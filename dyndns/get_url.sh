#!/bin/sh

# get_url.sh
# script to get the needed url to renew the dns register of a domain 
# (using ionos API)

API_KEY=$(cat user.key)
output=$(curl -X "POST" "https://api.hosting.ionos.com/dns/v1/dyndns" \
    -H "accept: application/json" \
    -H "X-API-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
        "domains": [
            "nrk19.com",
            "www.nrk19.com",
            "uptime-kuma.nrk19.com",
            "grafana.nrk19.com"
        ],
        "description": "Dynamic DNS"
    }') 

# process the curl and getting the updateUrl using jq
updateUrl=$(echo "$output" | jq -r '.updateUrl')

# save the url into a file and output its content
echo $updateUrl > update_url
cat update_url