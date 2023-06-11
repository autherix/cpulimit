#!/usr/bin/env bash

# Get current directory path
binpath=$(dirname "$(realpath "$0")")

echo "" > /tmp/cpulimit_count.ini

## Main Part

while true; do
    # Load config.conf file
    if [ -f "$binpath/cpulimit.conf" ]; then
        source "$binpath/cpulimit.conf"
    else
        source "/etc/cpulimit/cpulimit.conf"
        # if error, then exit 1
        if [ $? -ne 0 ]; then
            printf "Error: cpulimit.conf file not found in %s or /etc/cpulimit/cpulimit.conf\n or has some errors\nExitting" "$binpath"
            exit 1
        fi
    fi
    ## Source PATH-related files
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
    # Get current total cpu usage (consider all cores) percent
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    # Get current ram usage
    ram_usage=$(free | grep Mem | awk '{printf "%.2f%%\t\t\n", $3/$2 * 100.0}' | cut -d'%' -f1)
    # Check if system cpu usage is more than CPU_USAGE_LIMIT% or ram usage is more than RAM_USAGE_LIMIT%
    if (( $(echo "$cpu_usage > $CPU_USAGE_LIMIT" | bc -l) )) || (( $(echo "$ram_usage > $RAM_USAGE_LIMIT" | bc -l) )); then
        logger -s -t "cpulimit" "HIGH ALERT - CPU: $cpu_usage% - RAM: $ram_usage%"
        # Get the process ids which have more than CPU_KILL_LIMIT% total cpu usage(not oly per one core) OR more than RAM_KILL_LIMIT% ram usage
        pids=$(ps -eo pid,%cpu,%mem --sort=-%cpu | awk '{if ($2 > '"$CPU_KILL_LIMIT"' || $3 > '"$RAM_KILL_LIMIT"') print $1}')
        # Kill the processes
        for pid in $pids; do
            ps_cmd=$(ps -p $pid -o args=)
            # Check if this pid is in count list, if not then add it to count list with format pid:count
            if ! grep -q "$pid:" /tmp/cpulimit_count.ini; then
                echo "$pid:1" >> /tmp/cpulimit_count.ini
                count=1
            else
                # else, get the count of this pid from count list, increment it by 1 and update the line in the file
                count=$(grep "$pid:" /tmp/cpulimit_count.ini | cut -d':' -f2) 
                count=$((count+1))
                sed -i "s/$pid:.*/$pid:$count/g" /tmp/cpulimit_count.ini
            fi
            # Iterate over the items in EXCEPTIONS array (of strings), check each item with process full command, use grep with regex to see if it matches
            for exception in "${EXCEPTIONS[@]}"; do
                if echo "$ps_cmd" | grep -E "$exception"; then
                    logger -s -t "cpulimit" "Process: $pid - command: $ps_cmd - is in exceptions list, skipping - Count: $count"
                    # Add the command to notification exception list
                    # If (DISCORD_NOTIFICATION is true) AND (pid count is a multiple of 10 OR is 1), then send notification
                    # If EXCEPTION_COUNT_NOTIF is not set, then set it to default value = 30
                    if [ -z "$EXCEPTION_COUNT_NOTIF" ]; then
                        EXCEPTION_COUNT_NOTIF=30
                    fi
                    if [ "$DISCORD_NOTIFICATION" = true ] && (( $count % $EXCEPTION_COUNT_NOTIF== 0 || $count == 1 )); then
                        msg_body="Process: $pid\nFull Command: $ps_cmd\nis in exceptions list, skipping\nCount: $count"
                        # if DISCORD_CHANNEL_HANDLE is not set, then set it to default value = cpulimit
                        if [ -z "$DISCORD_CHANNEL_HANDLE" ]; then
                            DISCORD_CHANNEL_HANDLE="cpulimit"
                        fi
                        notifio --title "cpulimit - Process in Exceptions List" --discord -ch $DISCORD_CHANNEL_HANDLE -m "$msg_body" > /dev/null 2>&1 &
                    fi
                    continue 2
                fi
            done

            ## KILL ## 
            kill -9 $pid

            # if process with that pid is still running, then log error 
            if ps -p $pid > /dev/null; then
                logger -s -t "cpulimit" "Failed to kill process: $pid - command: $ps_cmd"
                # If DISCORD_NOTIFICATION is true, run notifio using run_with_path.sh in current directory
                if [ "$DISCORD_NOTIFICATION" = true ]; then
                    msg_body="Failed to kill process: $pid\nFull Command: $ps_cmd"
                    # if DISCORD_CHANNEL_HANDLE is not set, then set it to default value = cpulimit
                    if [ -z "$DISCORD_CHANNEL_HANDLE" ]; then
                        DISCORD_CHANNEL_HANDLE="cpulimit"
                    fi
                    notifio --title "cpulimit - Failed to Kill Process" --discord -ch $DISCORD_CHANNEL_HANDLE -m "$msg_body" > /dev/null 2>&1 &
                fi
            else
                logger -s -t "cpulimit" "Killed Process: $pid - command: $ps_cmd"
                msg_body="Killed Process: $pid\nFull Command: $ps_cmd"
                if [ "$DISCORD_NOTIFICATION" = true ]; then
                    # if DISCORD_CHANNEL_HANDLE is not set, then set it to default value = cpulimit
                    if [ -z "$DISCORD_CHANNEL_HANDLE" ]; then
                        DISCORD_CHANNEL_HANDLE="cpulimit"
                    fi
                    notifio --title "cpulimit - Killed Process" --discord -ch $DISCORD_CHANNEL_HANDLE -m "$msg_body" > /dev/null 2>&1 &
                fi
            fi
        done
    fi
    sleep $CHECK_INTERVAL
done