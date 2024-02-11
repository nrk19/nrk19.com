# Automated web server deploy

Deployment of a web server with analytics & monitoring functions using Docker containers.

Dependencies: 
- `docker`
- `docker-compose`
- `make`

## Table of contents
  - [Deploy](#deploy)
  - Previous configuration
    - [Router configuration](#router-configuration)
    - [Dynamic DNS setup](#dynamic-dns-setup)
  - Web server configuration
    - [Obtain the SSL certificates using Certbot](#obtaining-ssl-certificates-with-cerbot)
    - [Grafana and Prometheus monitoring tools](#grafana-and-prometheus-monitoring-tools)
    - [Apache configuration](#apache-configuration)
  - [Benchmarks and tests](#benchmarks-and-tests)

## Deploy

The deployment was automated using `make` and `docker-compose`. 
> [!NOTE]
> For the SSL certs to work you will need to replace *nrk19.com* with your domain in the config files ([Makefile](Makefile), [web/httpd.conf](web/httpd.conf) and [certbot/httpd.conf](certbot/httpd.conf))
- Deploy generating/renewing SSL certificates: `make all`

- Just deploy the server without generating new certificates: `make deploy`

## Previous configuration

### Router configuration

For our server to  be accessible from the Internet, we will need to map the ports from our router to our server, since the server itself doesn't have a public IP (due to NAT protocol), it accesses to the Internet through the router's IP.
In most cases we can access to the router configuration by writing our router local IP in a web navigator, and then we will look for the ports section. Our intention is to map the port **80** and **443** of our router to the ports **80** and **443** in our server, so the requests done by the users can be listened by our server.
Once our ports are mapped from router to server we can keep going.

### Dynamic DNS setup

Since our ISP are not providing us an static IP we will need to set a solution to this. We chosen IONOS as our provider, so we will use the IONOS API. The first step is to get an **API key** that allow us to interact with the IONOS API. *See : [Getting started with the IONOS APIs](https://developer.hosting.ionos.es/docs/getstarted)*.  

Once we got our API key we will need to authorize the Dynamic DNS service to interact with our domain. We will go to [https://developer.hosting.ionos.es/docs/dns](https://developer.hosting.ionos.es/docs/dns) and click over **Authorize**.

Now we will make a POST request with the following content: 
> [!NOTE]
> Where *${API_KEY}* is your valid API key and *nrk19.com* is your domain
```sh
curl -X "POST" "https://api.hosting.ionos.com/dns/v1/dyndns" \
    -H "accept: application/json" \
    -H "X-API-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "domains": [
            "nrk19.com",
            "www.nrk19.com",
        ],
        "description": "Dynamic DNS"
    }'
```
*Script: [dyndns/get_url.sh](dyndns/get_url.sh)*

If the request was successful, we will receive and answer similar to this:
```json
{
"bulkId": "22af3414-abbe-9e11-5df5-66fbe8e334b4",
"updateUrl": "https://ipv4.api.hosting.ionos.com/dns/v1/dyndns?q=dGVzdC50ZXN0", 
"domains": [
"example-zone.de",
"www.example-zone.de"
],
"description": "My DynamicDns"
}
```

We will use the **updateUrl** to renew the IP of our domain. 
`curl <update_url>`

To make sure that the IP is **always updated**, I created a container that is running cron and executing the curl command every minute, so as soon as the server is deployed, the IP is getting updated. 
I simply created an image that will run cron over the official docker debian image. I passed it a simple script to update the IP (using the URL we previously obtained) and a crontab that will be running the script every minute.

```Dockerfile
FROM debian:latest
RUN apt-get update && apt-get install cron curl -y
WORKDIR /app
COPY update.sh /app/update.sh
COPY update_url /app/update_url
RUN chmod +x /app/update.sh
COPY cronjob /etc/cron.d/cronjob
RUN chmod 0644 /etc/cron.d/cronjob
RUN crontab /etc/cron.d/cronjob
CMD ["cron", "-f", "/etc/cron.d/cronjob"]
```
*Content of [dyndns/Dockerfile](dyndns/Dockerfile)*


## Web server configuration

### Obtain SSL certificates with Cerbot

### Grafana and Prometheus monitoring tools

### Web server configuration

## Benchmarks and tests
