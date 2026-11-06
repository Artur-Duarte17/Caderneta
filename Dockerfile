# syntax=docker/dockerfile:1

# Etapa 1: build do Flutter Web.
# Ordem das camadas: do que muda MENOS para o que muda MAIS. Só o código do app (lib/, web/, assets/)
# invalida o build; mexer em docs/, test/, scripts/ ou README não refaz nada.
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# 1) Dependências: só refaz se o pubspec.yaml mudar.
# O lock local não é usado: o SDK da imagem fixa versões próprias (ex.: intl).
COPY pubspec.yaml ./
RUN flutter pub get

# 2) Apenas o que o build usa (nada de COPY . .).
COPY analysis_options.yaml ./
COPY web ./web
COPY assets ./assets
COPY lib ./lib

# Vazio = caminho relativo (/api/...), servido pelo proxy do nginx na mesma origem.
ARG API_URL=
# --no-web-resources-cdn: CanvasKit vem no pacote, não do gstatic (funciona sem internet externa).
RUN flutter build web --release --no-web-resources-cdn --dart-define=API_URL=${API_URL} --dart-define=MOCK_API=false

# Etapa 2: servir com NGINX
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
