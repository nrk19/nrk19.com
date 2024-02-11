#!/bin/sh
# update.sh
# (we can obtain the URL using the script get_url.sh)

curl $(cat /app/update_url)
if [ $? -ne 0 ]; then
    printf "$(date '+%d-%m-%y %T'): There was errors when trying to update the IP address\n"
else
    printf "$(date '+%d-%m-%y %T'): The IP address was updated successfully\n"
fi