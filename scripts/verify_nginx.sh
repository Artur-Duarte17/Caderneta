#!/usr/bin/env bash
set -euo pipefail

frontend_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d /tmp/caderneta-nginx.XXXXXX)
test_name="caderneta-frontend-check-$$"
cleanup() {
  docker rm -f "$test_name-web" "$test_name-api" >/dev/null 2>&1 || true
  docker network rm "$test_name" >/dev/null 2>&1 || true
  rm -rf -- "$test_dir"
}
trap cleanup EXIT
test -f "$frontend_dir/build/web/index.html"

docker run --rm --add-host backend:127.0.0.1 \
  -v "$frontend_dir/nginx.conf:/etc/nginx/conf.d/default.conf:ro" nginx:alpine nginx -t

# Upstream descartável: este teste verifica o proxy, sem usar dados ou serviços do backend.
cat > "$test_dir/upstream.conf" <<'NGINX'
server {
    listen 8080;
    default_type application/json;
    add_header Cache-Control "no-store" always;
    add_header X-Received-Uri $request_uri always;
    location = /api/auth/csrf {
        add_header Cache-Control "no-store";
        add_header Set-Cookie "SESSION=fixture; Path=/; HttpOnly; SameSite=Lax";
        add_header X-Received-Uri $request_uri;
        return 200 '{"token":"fixture","headerName":"X-CSRF-TOKEN"}';
    }
    location /api/ {
        return 401 '{"code":"NAO_AUTENTICADO","message":"Entre novamente."}';
    }
}
NGINX
docker network create "$test_name" >/dev/null
docker create --rm --name "$test_name-api" --network "$test_name" --network-alias backend nginx:alpine >/dev/null
# docker cp funciona também no Docker Desktop sem compartilhar /tmp com a VM.
docker cp "$test_dir/upstream.conf" "$test_name-api:/etc/nginx/conf.d/default.conf"
docker start "$test_name-api" >/dev/null
docker run --rm -d --name "$test_name-web" --network "$test_name" -p 127.0.0.1::80 \
  -v "$frontend_dir/nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
  -v "$frontend_dir/build/web:/usr/share/nginx/html:ro" nginx:alpine >/dev/null
test_address=$(docker port "$test_name-web" 80/tcp)
python3 - "$test_address" <<'PY'
import json,sys,time,urllib.request,urllib.error
base='http://'+sys.argv[1]
def get(path):
    try: response=urllib.request.urlopen(base+path,timeout=3)
    except urllib.error.HTTPError as error: response=error
    return response.status,response.read().decode(),response.headers
for attempt in range(20):
    try:
        status,body,headers=get('/clientes')
        break
    except OSError:
        if attempt==19: raise
        time.sleep(.2)
assert status==200 and 'flutter_bootstrap.js' in body, 'fallback SPA'
status,body,headers=get('/api/auth/csrf')
assert status==200 and json.loads(body)['headerName']=='X-CSRF-TOKEN', 'JSON upstream'
assert headers['X-Received-Uri']=='/api/auth/csrf', 'URI preservada'
assert 'HttpOnly' in headers['Set-Cookie'], 'Set-Cookie preservado'
assert headers['Cache-Control']=='no-store', 'cache upstream preservado'
status,body,headers=get('/api/restrito')
assert status==401 and json.loads(body)['code']=='NAO_AUTENTICADO', 'erro JSON preservado'
status,_,_=get('/api')
assert status==404, '/api sem fallback SPA'
print('nginx: sintaxe, SPA, proxy, URI, cookie, cache e erro JSON aprovados (upstream simulado).')
PY
