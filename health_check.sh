#!/bin/bash

LOOP_COUNT=15
DELAY_SECONDS=5

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Memulai Health Check Loop sebanyak ${LOOP_COUNT} kali dengan jeda ${DELAY_SECONDS} detik..."
echo "--------------------------------------------------------------------------------"
echo "timestamp,target_host,http_code,total_time_seconds,status"
echo "--------------------------------------------------------------------------------"

HOST_DATA=$(ansible-inventory --list 2>/dev/null | jq -r '
    ( .["Project_multicloud_chaos"]?.hosts[]? | . + "," + . ),
    ( .["project_multicloud_chaos_gcp"]?.hosts[]? as $h | $h + "," + ._meta.hostvars[$h].ansible_host )
')

if [ -z "$HOST_DATA" ]; then
    echo -e "${RED}Tidak ada host yang ditemukan. Periksa inventaris.${NC}" >&2
    exit 1
fi

for (( i=1; i<=$LOOP_COUNT; i++ ))
do
    echo -e "${YELLOW}Pengecekan ke-$i dari $LOOP_COUNT...${NC}" >&2

    while IFS=, read -r host_name connection_target; do
        if [ -z "$host_name" ]; then continue; fi

        response=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" "http://$connection_target" --connect-timeout 5)
        http_code=$(echo "$response" | cut -d, -f1)
        total_time=$(echo "$response" | cut -d, -f2)

        if [[ "$http_code" == "200" ]]; then
            status="HEALTHY"
            color=$GREEN
        else
            status="UNHEALTHY"
            color=$RED
        fi

        printf "%s,%s,%s,%s,${color}%s${NC}\n" "$(date --iso-8601=seconds)" "$host_name" "$http_code" "$total_time" "$status"

    done <<< "$HOST_DATA" 

    if [ $i -lt $LOOP_COUNT ]; then
        sleep $DELAY_SECONDS
    fi
done

echo "--------------------------------------------------------------------------------"
echo -e "${GREEN}Health check loop selesai.${NC}"