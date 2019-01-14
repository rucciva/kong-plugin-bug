#!/bin/bash
set -euo pipefail

echo "hi!"

KONG_ADMIN_URL=${KONG_ADMIN_URL:-http://kong:8001}
until curl -s -o /dev/null "$KONG_ADMIN_URL" 2>&1; do echo "still waiting"; sleep 1; done

count=${1:-72}
for i in `seq 1 $count`; do
    echo "data; $i"
    serviceID=$(cat /proc/sys/kernel/random/uuid)
    curl \
        -fs \
        -o /dev/null \
        -X PUT \
        "$KONG_ADMIN_URL/services/$serviceID" \
        -d "protocol=http" \
        -d "host=mockbin.com" \
        -d "port=80" \
        -d "path=/request" 2>&1

    routeID=$(cat /proc/sys/kernel/random/uuid)
    curl \
        -fs \
        -o /dev/null \
        -X PUT \
        "$KONG_ADMIN_URL/routes/$routeID" \
        -d "protocols[]=http" \
        -d "paths[]=/api-$i/v1.0.0" \
        -d "service.id=$serviceID" 2>&1
    
    curl \
        -fs \
        -o /dev/null \
        -X PUT \
        "$KONG_ADMIN_URL/plugins/$(cat /proc/sys/kernel/random/uuid)" \
        -d "route.id=$routeID" \
        -d "name=oauth2" \
        -d "config.scopes=test" \
        -d "config.enable_client_credentials=true" 2>&1

    curl \
        -fs \
        -o /dev/null \
        -X PUT \
        "$KONG_ADMIN_URL/plugins/$(cat /proc/sys/kernel/random/uuid)" \
        -d "route.id=$routeID" \
        -d "name=cors" \
        -d "config.origins=.*\.domain\.net:\d+" 2>&1
    
    curl \
        -fs \
        -o /dev/null \
        -X PUT \
        "$KONG_ADMIN_URL/plugins/$(cat /proc/sys/kernel/random/uuid)" \
        -d "route.id=$routeID" \
        -d "name=acl" \
        -d "config.whitelist=api-$i" \
        -d "config.hide_groups_header=true" 2>&1

    consumerID=$(cat /proc/sys/kernel/random/uuid)
    curl \
        -fs \
        -o /dev/null \
        -X PUT \
        "$KONG_ADMIN_URL/consumers/$consumerID" \
        -d "custom_id=$consumerID"  2>&1

    curl \
        -fs \
        -o /dev/null \
        -X PUT \
        "$KONG_ADMIN_URL/plugins/$(cat /proc/sys/kernel/random/uuid)" \
        -d "route.id=$routeID" \
        -d "consumer.id=$consumerID" \
        -d "name=correlation-id" \
        -d "config.header_name=api-consumer-$i" 2>&1

done