FROM nginx:alpine
RUN echo "<h1>Version 1.2.3</h1>" > /usr/share/nginx/html/index.html
