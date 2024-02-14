# Dockerfile
# this image will run cron to update dns every minute
# it will be added into the compose file so as soon as the server is running
# the ip will be automatically updating

FROM debian:latest
RUN apt-get update && apt-get install cron curl -y
WORKDIR /app
COPY update.sh update.sh
COPY update_url update_url
RUN chmod +x update.sh 
COPY cronjob /etc/cron.d/cronjob
RUN chmod 0644 /etc/cron.d/cronjob
RUN crontab /etc/cron.d/cronjob
CMD ["cron", "-f", "/etc/cron.d/cronjob"]