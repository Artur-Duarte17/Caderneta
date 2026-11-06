# Etapa 1: build do Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
# O lock local não é usado: o SDK da imagem fixa versões próprias (ex.: intl).
COPY pubspec.yaml ./
RUN flutter pub get
COPY . .
# Vazio = caminho relativo (/api/...), servido pelo proxy do nginx na mesma origem.
ARG API_URL=
# --no-web-resources-cdn: CanvasKit e fontes vêm no pacote, não do gstatic (funciona sem internet externa).
RUN flutter build web --release --no-web-resources-cdn --dart-define=API_URL=${API_URL} --dart-define=MOCK_API=false

# Etapa 2: servir com NGINX
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
