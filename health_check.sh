#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' 

echo -e "${YELLOW}Mengambil daftar IP terbaru dari inventaris Ansible...${NC}"

TARGET_IPS=$(ansible-inventory --list -y | jq -r '.["project_multicloud-chaos"].hosts[]?, .["project_multicloud-chaos-gcp"].hosts[]?')

if [ -z "$TARGET_IPS" ]; then
    echo -e "${RED}Tidak ada host yang ditemukan. Pastikan inventaris dan tag/label sudah benar.${NC}"
    exit 1
fi

echo "Host yang akan diuji:"
echo "$TARGET_IPS"
echo "-------------------------------------"
echo "timestamp,target_ip,http_code,total_time_seconds,status"
echo "-------------------------------------"

for ip in $TARGET_IPS; do
    response=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" "http://$ip" --connect-timeout 2)

    http_code=$(echo "$response" | cut -d, -f1)
    total_time=$(echo "$response" | cut -d, -f2)

    if [ "$http_code" -eq 200 ]; then
        status="HEALTHY"
        color=$GREEN
    else
        status="UNHEALTHY"
        color=$RED
    fi

    printf "%s,%s,%s,%s,${color}%s${NC}\n" "$(date --iso-8601=seconds)" "$ip" "$http_code" "$total_time" "$status"
done