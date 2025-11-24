FROM nginx:alpine

# Copia todos os arquivos HTML/CSS/JS para o NGINX
COPY . /usr/share/nginx/html

# Expõe a porta 80
EXPOSE 80