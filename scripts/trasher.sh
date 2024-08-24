#!/bin/bash

total_space_kb=$(df / | tail -n 1 | awk '{print $4}')

threshold_mb=200
threshold_kb=$((threshold_mb * 1024))

if [ $(echo "$total_space_kb < $threshold_kb" | bc) -eq 1 ]; then
    find /var/log/vpn -type f -name "*.log" -mtime +30 -exec rm {} \;
fi
