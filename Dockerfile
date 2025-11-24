FROM nginx:alpine

# Copia a configuração personalizada do NGINX
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copia todos os arquivos HTML/CSS/JS para o NGINX
COPY . /usr/share/nginx/html

# Expõe a porta 80
EXPOSE 80