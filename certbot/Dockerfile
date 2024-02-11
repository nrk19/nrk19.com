# src: https://www.linkedin.com/pulse/use-apache-ssllets-encrypt-docker-leon-sczepansky
FROM alpine:latest
LABEL author="Leon Sczepansky"
ENV server_name=localhost
RUN apk add --no-cache apache2
RUN rm -rf /var/www/localhost/cgi-bin/
CMD exec /usr/sbin/httpd -D FOREGROUND -f /etc/apache2/httpd.conf
