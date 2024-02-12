# Web Server Deploy

Deployment of a web server with analytics & monitoring functions using Docker containers.

Dependencies: 
- `docker`
- `docker-compose`
- `make`

## Table of contents
  - [Deploy](#deploy)
  - [Previous configuration](#previous-configuration)
    - [Router configuration](#router-configuration)
    - [Dynamic DNS setup](#dynamic-dns-setup)
  - [Web server configuration](#web-server-configuration)
    - [Obtain the SSL certificates using Certbot](#obtaining-ssl-certificates-with-certbot)
    - [Apache configuration](#apache-configuration)
    - [Grafana and Prometheus monitoring tools](#grafana-and-prometheus-monitoring-tools)
      - [Prometheus configuration](#prometheus-configuration)
      - [Grafana configuration](#grafana-configuration)
      - [Grafana virtual host creation](#grafana-virtual-host-creation)
  - [Benchmark](#benchmark)
      - [Conclusions](#conclusions)

## Deploy

The deployment was automated using `make` and `docker-compose`. 

> [!IMPORTANT]
> For the SSL certs to work you will need to edit [.env](.env) and replace the values with the your server info.

- Deploy the server and generate/renew SSL certificates: `make all`
- Just deploy the server without generating new certificates: `make deploy`

## Previous configuration

### Router configuration

Since the server itself doesn't have a public IP (due to NAT protocol), it accesses to the Internet through the router's IP, so for our web to be accessible from the Internet, we will need to map the port 80 and 443 from our router to our server. So all the requests done to our router's public IP will be redirect to our server.

In most cases we can access to the router configuration by writing our router local IP in a web navigator, and then we will look for the ports section. Sometimes we can locate it in the *Advanced configuration* section, sometimes it will be called *NAT/PAT*, but it will totally depends on the router, so the best way to do it is to check your router's manual.

Once our ports are mapped, we can keep going.

### Dynamic DNS setup

> Only tested on IONOs.

Since our ISP are not providing us an static IP we will need to set a solution to this. We chosen IONOS as our provider, so we will use the IONOS API. The first step is to get an **API key** that allow us to interact with the IONOS API. *See : [https://developer.hosting.ionos.es/docs/getstarted](https://developer.hosting.ionos.es/docs/getstarted)*.  

Once we got our API key we will need to authorize the Dynamic DNS service to interact with our domain. We will go to [https://developer.hosting.ionos.es/docs/dns](https://developer.hosting.ionos.es/docs/dns) and click over **Authorize**.

![image-not-found](screenshots/ionos-dyndns-auth.png)
*Caption: Authorize Dynamic DNS API.*

Now we will make a POST request with the following content: 
> Where *API_KEY* is your valid API key and *nrk19.com* is your domain
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
So to renew the IP, we just run: `curl <update_url>`

> You can obtain the url to update your IP by creating a file called user.key with your IONOS' API key and running the script [get_url](dyndns/get_url.sh).
> The script will generated the file **update_url**, needed by the cron's container. 

To make sure that the IP is **always updated**, We created a container that is running cron and updating the IP every minute, so as soon as the server is deployed, the IP is getting updated. 
We simply created an image that will run cron (using the official Docker's Debian image as template) . We pass the container a simple script to update the IP (using the URL we previously obtained) and a crontab that will be running the script every minute.Also it will log the changes into **/var/log/cron.log** inside of the container.

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

### Obtain SSL certificates with Certbot

In order to provide a safe an encrypted connection to our server, we will need a valid certificate. We will do it using [certbot](https://github.com/certbot/certbot) which is a docker image provide by **Let's encrypt**, an open and free certificate authority.

We will need to create a temporary server listening on port 80 and associated with the domain we want to certificate. In our case we will use the official apache image (httpd). Once we get the certificated we won't need it anymore. 

```
├── certbot
│   ├── htdocs
│   │   └── index.html
│   └── httpd.conf
```
*Temporary web server directory structure*

With the following configuration file: 

> Replace *nrk19.com* and *admin@nrk19.com* with your domain's info

```apache
ServerRoot /usr/local/apache2
Listen 80
User www-data
Group www-data

ServerName nrk19.com
ServerAdmin admin@nrk19.com
ServerTokens Prod
ServerSignature Off

ErrorLog logs/error.log
LogLevel info
DocumentRoot  "/usr/local/apache2/htdocs"

<Directory /.well-known/acme-challenge>
        Require all granted
</Directory>

<Directory "/usr/local/apache2/htdocs">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
```
*Content of [certbot/httpd.conf](certbot/httpd.conf)*

And we will run the container with the following command: 

```sh
docker run -d --rm --name le_apache \
  -p 8080:80 \
  -v $$PWD/certbot/httpd.conf:/usr/local/apache2/conf/httpd.conf \
  -v $$PWD/certbot/htdocs:/usr/local/apache2/htdocs/ \
  httpd
```
*Fragment of [Makefile](Makefile)*

With the server listening on port 80, we will now run the **certbot** container to obtain the certificates with the command:

```sh
docker run -it --rm --name certbot \
  -v $$PWD/certbot/html:/data/letsencrypt \
  -v certs:/etc/letsencrypt \
  certbot/certbot \
  certonly --webroot \
  --email jcg@nrk19.com --agree-tos --no-eff-email \
  --webroot-path=/data/letsencrypt \
  -d nrk19.com -d www.nrk19.com -d grafana.nrk19.com -d uptime-kuma.nrk19.com
```
*Fragment of [Makefile](Makefile)*

The certificates will be created on the container's directory `/etc/letsencrypt/`, so to keep the certificates we will map that directory to a docker volume called **certs**, and we will link it later to our main web server.

### Apache configuration

The main web server will be a Docker container running the official Apache image **httpd**.

Container deploy options:

```yaml
web:
  image: httpd:latest
  container_name: web
  volumes:
    - ./web/htdocs:/usr/local/apache2/htdocs
    - ./web/httpd.conf:/usr/local/apache2/conf/httpd.conf
    - certs:/etc/letsencrypt
  ports:
    - 8080:80
    - 4443:443
```
*Fragment of [compose.yaml](compose.yaml)*

We will map the docker volume *certs* to the container directory **/etc/letsencrypt**. The certificates will be located at **/etc/letsencrypt/live/[your-domain]/fullchain.pem** and **/etc/letsencrypt/live/[your-domain]/privkey.pem**. 

Also we will map the ports, and link the configuration file and the directory htdocs to the container.

> [!NOTE]
> The server will have two virtual hosts, one will be the *main server* and the other one will be the *Grafana* monitoring system (we will talk about this last one later). 

The main virtual host configuration is:

```apache
<VirtualHost *:443>
    ServerName www.nrk19.com
    DocumentRoot "/usr/local/apache2/htdocs"
    ErrorDocument 404 /error404.html
    ErrorDocument 403 /error403.html

    # document root
    <Directory "/usr/local/apache2/htdocs">
        Options -Indexes +FollowSymLinks 
        AllowOverride None
        Require all granted
    </Directory>

    # configure /status location using apache's default status mod
    # this stats will be needed to configure grafana
    <Location "/status">
        AuthType Basic
        AuthName "sysadmin"
        AuthUserFile "/usr/local/apache2/htdocs/.htpasswd_basic"
        SetHandler server-status
        Require user sysadmin
    </Location>

    # redirect /admin and /grafana to its virtual sites
    Redirect /admin https://uptime-kuma.nrk19.com/
    Redirect /grafana https://grafana.nrk19.com/
</VirtualHost>
```
*Fragment of [web/httpd.conf](web/httpd.conf)*

Basically, we configure custom error documents, enable at the location /status the mod `mod_status`, and also configure Basic authentication at the same location. In addition, we will redirect the requests to /grafana to the **Grafana Virtual Host** and  the requests to /admin will be redirect to the **Uptime-Kuma virtual host**.

The server will only provided SSL connections, so it will redirect all the requests it receives to port 80 to port 443 and it will refuse non-encrypted connections.

```apache
<VirtualHost *:80>
    Redirect / https://www.nrk19.com:443/
</VirtualHost>
```
*Fragment of [web/httpd.conf](web/httpd.conf)*

### Grafana and Prometheus monitoring tools

To provide our server with monitor and analytics functions, we will use [Grafana](https://github.com/grafana/grafana) in combination with [Prometheus](https://github.com/prometheus/prometheus) and [apache_exporter](https://github.com/Lusitaniae/apache_exporter).

#### Prometheus configuration

**Grafana** depends on a data source, we will use **Prometheus** to provide Grafana with the data it needs.

Prometheus needs the server's data to make the queries and display the graphs. To obtain the server's data we can use **apache_exporter**. It will take the information given by the default `mod_status` (which is running on location /status in our server) and transform it into a format that is understood by prometheus. 

So, the first step will be to obtain the server information. We will run the official apache_exporter container, and we will pass it the URL where we allocated the `mod_status` and the authentication (if needed). This is the container deploy config:

```yaml
apache-exporter:
  image: lusotycoon/apache-exporter
  container_name: apache-exporter
  depends_on:
    - web
  privileged: true
  expose:
    - 9117
  restart: unless-stopped
  extra_hosts:
  - "localhost:127.17.0.1"
  entrypoint: /bin/apache_exporter --scrape_uri="https://sysadmin:risa@nrk19.com/status?auto/"
```
*Fragment of [compose.yaml](compose.yaml)*

> We will pass our URL with the `--scrape_uri` flag.

The apache_exporter container will be listening at port 9117 and will be supplying the information needed by Prometheus.

Now, we need to indicate Prometheus where to get the data. We will create a file called `prometheus.yaml`, and we will indicate the socket of the host that have the data we want to display. In this case **apache-exporter:9117**

> [!NOTE]
> Since we have all the containers in the same compose file, docker-compose will resolve the addresses for us.

```yaml
global:
  scrape_interval: 1m

scrape_configs:
  - job_name: "apache_exporter"
    scrape_interval: 1m
    static_configs:
      - targets: ['apache-exporter:9117']  
```
*Content of [prometheus.yaml](prometheus.yaml)*

With the prometheus configuration file created, we now just need to run the prometheus container. The container will run with the following options:

```yaml
prometheus:
  image: prom/prometheus:latest
  container_name: prometheus
  depends_on:
    - apache-exporter
  restart: unless-stopped
  volumes:
    - ./prometheus.yaml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
    - '--web.console.libraries=/etc/prometheus/console_libraries'
    - '--web.console.templates=/etc/prometheus/consoles'
    - '--web.enable-lifecycle'
  expose:
    - 9090
```
*Fragment of [compose.yaml](compose.yaml)*

Prometheus is now ready and listening on port 9090.

#### Grafana configuration

Finally, we will run the Grafana container:

```yaml
grafana:
  image: grafana/grafana
  container_name: grafana
  depends_on:
    - prometheus
  expose:
    - 3000
  volumes:
    - grafana_data:/var/lib/grafana
```

> We created the docker volumes **grafana_data** and **prometheus_data** to have persistency of the data after we remove the containers.

With the grafana container running, we will access with a navigator to the url **http://grafana:3000** and a login page will be prompted. The default credentials are: `user=admin password=admin`. 

![image-not-found](screenshots/grafana-login.png)

*Caption: Grafana's login menu*

Once inside the Grafana main page, we will click on **Menu (located on the web's upper left side) > Connections > Add new connection**, and we will select *Prometheus* as data source.

![image-not-found](screenshots/prometheus-new-connection.png)

*Caption: select Prometheus as data source for Grafana*

We simply set the connection indicating the prometheus ip and port. In our case **http://prometheus:9090/**.

![image-not-found](screenshots/prometheus-ip.png)

*Caption: set the prometheus ip on grafana*

If the connection was successful we will see the following message:

![image-not-found](screenshots/prometheus-success.png)

*Caption: prometheus successfully connected*

After we connect both services, we should be able to create a new dashboard.

![image-not-found](screenshots/grafana-graph.png)

*Caption: apache_accesses_total graph*

#### Grafana Virtual Host Creation

Now we have **Grafana** running in our local network. What we want to do now is redirect all the requests made to **https://nrk19.com/grafana/** to our grafana container. We will add the following virtual host to our httpd.conf: (the Location authentication setup is optional)

> [!IMPORTANT]
> For this virtual host to work, we will need to create a subdomain and configure it so it points to the same IP address as the main domain.

```apache
<VirtualHost *:443>
    ServerName grafana.nrk19.com
    ProxyPreserveHost on
    ProxyPass / http://grafana:3000/
    ProxyPassReverse / http://grafana:3000/

    <Location "/">
        AuthType Digest
        AuthName "admin"
        AuthUserFile "/usr/local/apache2/htdocs/.htpasswd"
        Require user admin
    </Location>
</VirtualHost>
```
*Fragment of [web/httpd.conf](web/httpd.conf)*

And now that the Virtual Host is created, we will add this line into our main virtual host.

```apache
Redirect /grafana https://grafana.nrk19.com/
```
*Fragment of [web/httpd.conf](web/httpd.conf)*

## Benchmark

To evaluate the efficiency of our server we will use **ab** (apache's benchmark). In most linux distributions, it is present on the package `apache-utils`.

We put the server into efficiency tests:
- **100 clients and 1000 requests**:

<img src="screenshots/ab-100c-1000n.png" width="70%" alt="image-not-found">

*Caption: 100 clients and 1000 requests without - k flag*

<img src="screenshots/ab-100c-1000n-k.png" width="70%" alt="image-not-found">

*Caption: 100 clients and 1000 requests with -k flag*

- **1000 clients and 1000 requests**:

<img src="screenshots/ab-1000c-1000n.png" width="70%" alt="image-not-found">

*Caption: 1000 clients and 1000 requests without -k flag*

<img src="screenshots/ab-1000c-1000n-k.png" width="70%" alt="image-not-found">

*Caption: 1000 clients and 1000 requests with -k flag*

### Conclusions

- The first test with high concurrency (1000) shows lower Requests per Second and higher Time per Request compared to the subsequent tests with lower concurrency.
- Enabling Keep-Alive connections (-k flag) in the second and forth tests significantly improves performance.
- The first test with 100 concurrency exhibits the highest Requests per Second and the lowest Time per Request, indicating improved efficiency at lower concurrency levels
