#!/usr/bin/env bash

while true; do
    printf "Checking system cpu and ram usage...\n"
    # Get current cpu usage
    cpu_usage=$(top -bn1 | grep load | awk '{printf "%.2f%%\t\t\n", $(NF-2)}' | cut -d'%' -f1)
    # Get current ram usage
    ram_usage=$(free | grep Mem | awk '{printf "%.2f%%\t\t\n", $3/$2 * 100.0}' | cut -d'%' -f1)
    # Check if system cpu usage is more than 75% or ram usage is more than 75%
    if (( $(echo "$cpu_usage > 75.0" | bc -l) )) || (( $(echo "$ram_usage > 75.0" | bc -l) )); then
        # Get the 10 highest cpu usage processes sorted by highest cpu usage
        processes=$(ps -eo pid,pcpu,pmem,comm --sort=-%cpu | awk 'NR>1' | head -n 10)

        # Loop through the processes, if any process has cpu usage more than 70% kill it
        while read -r pid cpu mem cmd; do
            if (( $(echo "$cpu > 70.0" | bc -l) )); then
                logger -t cpulimit "Killing process: PID=$pid, CPU=$cpu%, RAM=$mem%, Command=$cmd"
                # kill with code 9 to make sure the process is killed
                kill -9 "$pid"
            fi
        done <<< "$processes"

        # Get the 10 highest ram usage processes sorted by highest ram usage
        processes=$(ps -eo pid,pcpu,pmem,comm --sort=-%mem | awk 'NR>1' | head -n 10)

        # Loop through the processes, if any process has ram usage more than 70% kill it
        while read -r pid cpu mem cmd; do
            if (( $(echo "$mem > 70.0" | bc -l) )); then
                logger -t cpulimit "Killing process: PID=$pid, CPU=$cpu%, RAM=$mem%, Command=$cmd"
                # kill with code 9 to make sure the process is killed
                kill -9 "$pid"
            fi
        done <<< "$processes"
    fi

    sleep 20
done