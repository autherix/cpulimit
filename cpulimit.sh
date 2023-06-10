#!/usr/bin/env bash

binpath=$(dirname "$(realpath "$0")")

while true; do
    # Get current total cpu usage (consider all cores) percent
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    # Get current ram usage
    ram_usage=$(free | grep Mem | awk '{printf "%.2f%%\t\t\n", $3/$2 * 100.0}' | cut -d'%' -f1)
    # Check if system cpu usage is more than 85% or ram usage is more than 85%
    if (( $(echo "$cpu_usage > 95.0" | bc -l) )) || (( $(echo "$ram_usage > 95.0" | bc -l) )); then
        # Kill the processes which have more than 85% cpu usage OR more than 85% ram usage
        logger -s -t "cpulimit" "HIGH ALERT - CPU: $cpu_usage% - RAM: $ram_usage%"
        # Get the process ids which have more than 85% total cpu usage(not oly per one core) OR more than 85% ram usage
        pids=$(ps -eo pid,%cpu,%mem --sort=-%cpu | awk '{if ($2 > 85.0 || $3 > 85.0) print $1}')
        # pids=$(ps -eo pid,%cpu,%mem --sort=-%cpu | awk '{if ($2 > 85.0 || $3 > 85.0) print $1}')
        # Kill the processes
        for pid in $pids; do
            srclist=()
            # define an empty array
            declare -a srclist
            # iterate over lines of bashrc_content and echo them
            while IFS= read -r line; do
                # If line starts with 'source', then add it to srclist
                if [[ $line == source* ]]; then
                    # select everything after 'source '
                    srclist+=("${line:7}")
                fi
            done < ~/.bashrc
            for i in "${srclist[@]}"
            do
                source "$i" > /dev/null 2>&1
            done
            msg_body="Killing Process: $pid\nFull Command: $(ps -p $pid -o args=)"
            logger -s -t "cpulimit" "Kill Process: $pid - command: $(ps -p $pid -o args=)"
            kill -9 $pid
            # if process with that pid is still running, then log error 
            if ps -p $pid > /dev/null; then
                logger -s -t "cpulimit" "Failed to kill process: $pid"
                msg_body="Failed to kill process: $pid\nFull Command: $(ps -p $pid -o args=)"

                # run notifio using run_with_path.sh in current directory
                notifio --title "cpulimit - Killed Process" --discord -ch cpulimit -m "$msg_body" > /dev/null 2>&1 &
            fi

            # run notifio using run_with_path.sh in current directory
            notifio --title "cpulimit - Killing Process" --discord -ch cpulimit -m "$msg_body" > /dev/null 2>&1 &
        done
    fi
    sleep 5
done