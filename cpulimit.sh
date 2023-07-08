#!/usr/bin/env bash

# Get current directory path
binpath=$(dirname "$(realpath "$0")")

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

echo "" > /tmp/cpulimit_count.ini

## Main Part

while true; do
    # read the count list file and remove the lines which have pid which are not running anymore
    sed -i '/^$/d' /tmp/cpulimit_count.ini  # remove empty lines
    while read -r line; do
        pid=$(echo "$line" | cut -d':' -f1)
        if ! ps -p $pid > /dev/null; then
            sed -i "/$pid:.*/d" /tmp/cpulimit_count.ini
        fi
    done < /tmp/cpulimit_count.ini
    sed -i '/^$/d' /tmp/cpulimit_count.ini 
    # Get current total cpu usage (consider all cores) percent
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    # Get current ram usage
    ram_usage=$(free | grep Mem | awk '{printf "%.2f%%\t\t\n", $3/$2 * 100.0}' | cut -d'%' -f1)
    # printf "CPU: %s%%\t\tRAM: %s%%\n" "$cpu_usage" "$ram_usage"
    # Check if system cpu usage is more than CPU_USAGE_LIMIT% or ram usage is more than RAM_USAGE_LIMIT%
    if (( $(echo "$cpu_usage > $CPU_USAGE_LIMIT" | bc -l) )) || (( $(echo "$ram_usage > $RAM_USAGE_LIMIT" | bc -l) )); then
        logger -s -t "cpulimit" "HIGH ALERT - CPU: $cpu_usage% - RAM: $ram_usage%"
        # Get the process ids which have more than CPU_KILL_LIMIT% total cpu usage(not oly per one core) OR more than RAM_KILL_LIMIT% ram usage
        pids=$(ps -eo pid,%cpu,%mem --sort=-%cpu | awk '{if ($2 > '"$CPU_KILL_LIMIT"' || $3 > '"$RAM_KILL_LIMIT"') print $1}')
        # pids=$(ps -eo pid,%cpu,%mem --sort=-%cpu | awk '{if ($2 > 60 || $3 > 50) print $1}')
        # printf "pids: %s\n" "$pids"
        # Kill the processes
        for pid in $pids; do
            ps_cmd=$(ps -p $pid -o args=)
            # if COMMAND_MAX_LENGTH not set, then set it to default value = 200
            if [ -z "$COMMAND_MAX_LENGTH" ]; then
                COMMAND_MAX_LENGTH=200
            fi
            # If ps_cmd is longer than $COMMAND_MAX_LENGTH characters, then truncate it
            if [ ${#ps_cmd} -gt $COMMAND_MAX_LENGTH ]; then
                # pick about half of COMMAND_MAX_LENGTH characters from start and end of ps_cmd, +1 if odd number
                if (( $COMMAND_MAX_LENGTH % 2 == 0 )); then
                    ps_cmd_truncated="${ps_cmd:0:$((COMMAND_MAX_LENGTH/2))}  .......  ${ps_cmd: -$((COMMAND_MAX_LENGTH/2))}"
                else
                    ps_cmd_truncated="${ps_cmd:0:$((COMMAND_MAX_LENGTH+1/2))}  .......  ${ps_cmd: -$((COMMAND_MAX_LENGTH+1/2))}"
                fi
            else
                ps_cmd_truncated=$ps_cmd
            fi
            # Check if this pid is in count list, if not then add it to count list with format pid:count
            if ! grep -q "$pid:" /tmp/cpulimit_count.ini; then
                # echo "$pid:1" >> /tmp/cpulimit_count.ini
                printf "%s:1\n" "$pid" >> /tmp/cpulimit_count.ini
                count=1
            else
                # else, get the count of this pid from count list, increment it by 1 and update the line in the file
                count=$(grep "$pid:" /tmp/cpulimit_count.ini | cut -d':' -f2) 
                count=$((count+1))
                sed -i "s/$pid:.*/$pid:$count/g" /tmp/cpulimit_count.ini
            fi
            # Iterate over the items in EXCEPTIONS array (of strings), check each item with process full command, use grep with regex to see if it matches
            for exception in "${EXCEPTIONS[@]}"; do
                # printf "current exception: %s\n" "$exception"
                if echo "$ps_cmd" | grep -E "$exception" > /dev/null 2>&1 ; then
                    logger -s -t "cpulimit" "Process: $pid - command: $ps_cmd_truncated - is in exceptions list, skipping - Count: $count"
                    # Add the command to notification exception list
                    # If EXCEPTION_COUNT_NOTIF is not set, then set it to default value = 30
                    if [ -z "$EXCEPTION_COUNT_NOTIF" ]; then
                        EXCEPTION_COUNT_NOTIF=30
                    fi
                    # If (DISCORD_NOTIFICATION is true) AND (pid count is a multiple of 10), then send notification
                    if [ "$DISCORD_NOTIFICATION" = true ] && [ $((count % EXCEPTION_COUNT_NOTIF)) -eq 0 ]; then
                        # if [ "$DISCORD_NOTIFICATION" = true ] && (( $count % $EXCEPTION_COUNT_NOTIF== 0 || $count == 1 )); then
                        msg_body="Process: $pid\nFull Command: \`$ps_cmd_truncated\`\nis in exceptions list, skipping\nMatches Pattern: \`$exception\`\nCount: $count"
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
            # kill -9 $pid > /dev/null 2>&1

            # get the CPU and RAM usage of this process
            cpu_usage=$(ps -p $pid -o %cpu | tail -n 1)
            ram_usage=$(ps -p $pid -o %mem | tail -n 1)

            # the limited usage should be 70% of the current usage
            cpu_limit=$(echo "$cpu_usage * 0.7" | bc -l)
            
            # renice -n 19 -p $pid > /dev/null 2>&1
            cpulimit -p $pid -l $cpu_limit -z &

            sleep 1

            # get the CPU and RAM usage of this process
            cpu_usage=$(ps -p $pid -o %cpu | tail -n 1)
            ram_usage=$(ps -p $pid -o %mem | tail -n 1)
            total_cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
            total_ram_usage=$(free | grep Mem | awk '{printf "%.2f%%\t\t\n", $3/$2 * 100.0}' | cut -d'%' -f1)

            # if process with that pid is still using high CPU or RAM, then log error
            if (( $(echo "$cpu_usage > $CPU_KILL_LIMIT" | bc -l) )) || (( $(echo "$ram_usage > $RAM_KILL_LIMIT" | bc -l) )); then
                logger -s -t "cpulimit" "Failed to limit process: $pid - command: $ps_cmd_truncated"
                # If DISCORD_NOTIFICATION is true, run notifio using run_with_path.sh in current directory
                if [ "$DISCORD_NOTIFICATION" = true ]; then
                    # Get the CPU and RAM usage again
                    msg_body="Failed to limit process: $pid\nSystem Load: CPU: $total_cpu_usage% - RAM: $total_ram_usage%\nProcess Usage: CPU: $cpu_usage% - RAM: $ram_usage%\nFull Command: \`$ps_cmd_truncated\`"
                    # if DISCORD_CHANNEL_HANDLE is not set, then set it to default value = cpulimit
                    if [ -z "$DISCORD_CHANNEL_HANDLE" ]; then
                        DISCORD_CHANNEL_HANDLE="cpulimit"
                    fi
                    notifio --title "cpulimit - Failed to Limit Process" --discord -ch $DISCORD_CHANNEL_HANDLE -m "$msg_body" > /dev/null 2>&1 &
                fi
            else
                logger -s -t "cpulimit" "Limited Process: $pid - command: $ps_cmd_truncated"
                # logger -s -t "cpulimit" "Killed Process: $pid - command: $ps_cmd_truncated"
                msg_body="Limited Process: $pid\nSystem Load: CPU: $total_cpu_usage% - RAM: $total_ram_usage%\nProcess Usage: CPU: $cpu_usage% - RAM: $ram_usage%\nFull Command: \`$ps_cmd_truncated\`"
                # msg_body="Killed Process: $pid\nFull Command: \`$ps_cmd_truncated\`"
                if [ "$DISCORD_NOTIFICATION" = true ]; then
                    # if DISCORD_CHANNEL_HANDLE is not set, then set it to default value = cpulimit
                    if [ -z "$DISCORD_CHANNEL_HANDLE" ]; then
                        DISCORD_CHANNEL_HANDLE="cpulimit"
                    fi
                    notifio --title "cpulimit - Limited Process" --discord -ch $DISCORD_CHANNEL_HANDLE -m "$msg_body" > /dev/null 2>&1 &
                    # notifio --title "cpulimit - Killed Process" --discord -ch $DISCORD_CHANNEL_HANDLE -m "$msg_body" > /dev/null 2>&1 &
                fi
            fi
        done
    fi
    sleep $CHECK_INTERVAL
done