# syntax=docker/dockerfile:1

# Etapa 1: Flutter oficial em versão FIXA, conferido por SHA-256 (sem imagem de terceiros, sem "stable" flutuante).
# Ao atualizar: troque versão e hash pelos de
# https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
# e mantenha o mesmo valor no CI (.github/workflows) e no pubspec.lock.
FROM debian:bookworm-slim AS flutter
ARG FLUTTER_VERSION=3.47.9
ARG FLUTTER_SHA256=25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSLo /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/flutter.tar.xz -C /opt && rm /tmp/flutter.tar.xz \
    && git config --system --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --enable-web && flutter precache --web

# Etapa 2: build do app. Camadas do que muda MENOS para o que muda MAIS.
FROM flutter AS build
WORKDIR /app
# Dependências: exatamente as do pubspec.lock (falha se o lock estiver inconsistente).
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY analysis_options.yaml ./
COPY web ./web
COPY assets ./assets
COPY lib ./lib
# Vazio = caminho relativo (/api/...), na mesma origem (nginx local ou rewrite do Firebase Hosting).
ARG API_URL=
# --no-web-resources-cdn: CanvasKit vem no pacote, não do gstatic (funciona sem internet externa).
RUN flutter build web --release --no-web-resources-cdn --dart-define=API_URL=${API_URL} --dart-define=MOCK_API=false

# Etapa 3: servir com NGINX (ambiente local / compose)
FROM nginx:1.30-alpine
# Correções de segurança do sistema publicadas depois da imagem base.
RUN apk upgrade --no-cache
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
