#!/usr/bin/env bash

while true; do
    # Get current total cpu usage (consider all cores) percent
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    # Get current ram usage
    ram_usage=$(free | grep Mem | awk '{printf "%.2f%%\t\t\n", $3/$2 * 100.0}' | cut -d'%' -f1)
    # Check if system cpu usage is more than 75% or ram usage is more than 75%
    if (( $(echo "$cpu_usage > 85.0" | bc -l) )) || (( $(echo "$ram_usage > 85.0" | bc -l) )); then
        # Kill the processes which have more than 80% cpu usage OR more than 80% ram usage
        logger -s -t "cpulimit" "CPU or RAM more than 85% - CPU: $cpu_usage% - RAM: $ram_usage%"
        # Get the process ids which have more than 80% cpu usage OR more than 80% ram usage
        pids=$(ps -eo pid,%cpu,%mem --sort=-%cpu | awk '{if ($2 > 80.0 || $3 > 80.0) print $1}')
        # Kill the processes
        for pid in $pids; do
            logger -s -t "cpulimit" "Killing process with pid: $pid - CPU: $cpu_usage% - RAM: $ram_usage%"
            kill -9 $pid
        done
    fi
    sleep 5
done