# Makefile
# this file will be used to deploy the web server and all the dependencies

# pre-deploy - obtain the certicates
# build the image used to pass the certbot test and get the certificates
# first we stop the compose if is running, since cerbot test web server conflict 
# with main web server
stop_lab:
	docker-compose down

# build the test server image
build_le_apache:
	docker build -t lets-encrypt-apache certbot

# run the container
run_le_apache:
	docker run -d --rm --name le_apache -p 8080:80 \
		-v $$PWD/certbot/httpd.conf:/etc/apache2/httpd.conf \
		-v $$PWD/certbot/html:/var/www/localhost/htdocs/ \
		lets-encrypt-apache

# get the certificates
# the certifacates will be stored inside a docker volume called certs
run_certbot:
	docker run -it --rm --name certbot \
		-v $$PWD/certbot/html:/data/letsencrypt \
		-v certs:/etc/letsencrypt \
		certbot/certbot \
		certonly --webroot \
		--email jcg@nrk19.com --agree-tos --no-eff-email \
		--webroot-path=/data/letsencrypt \
		-d nrk19.com -d www.nrk19.com -d grafana.nrk19.com -d uptime-kuma.nrk19.com

stop_le_apache:
	docker stop le_apache 

get_certs: stop_lab build_le_apache run_le_apache run_certbot stop_le_apache

# deploy the server using docker-compose 
deploy: 
	docker-compose up -d

# all command to obtain certs and deploy
all: get_certs deploy
