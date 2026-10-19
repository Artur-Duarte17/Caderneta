# Etapa 1: build do Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
# O lock local não é usado: o SDK da imagem fixa versões próprias (ex.: intl).
COPY pubspec.yaml ./
RUN flutter pub get
COPY . .
ARG API_URL=http://localhost:8080
RUN flutter build web --release --dart-define=API_URL=${API_URL}

# Etapa 2: servir com NGINX
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
