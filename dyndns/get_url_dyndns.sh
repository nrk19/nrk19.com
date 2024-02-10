#!/usr/bin/env bash

# get_url_dyndns.sh
# script to renew the dns register of a domain 
# using ionos API

API_KEY=$(cat nrk19.dyndns)

curl -X "POST" "https://api.hosting.ionos.com/dns/v1/dyndns" \
    -H "accept: application/json" \
    -H "X-API-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "domains": [
            "nrk19.com",
            "uptime-kuma.nrk19.com",
            "grafana.nrk19.com"
        ],
        "description": "Dynamic DNS"
    }'