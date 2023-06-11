#!/usr/bin/env bash

# Disable cpulimit.service
sudo systemctl disable cpulimit.service > /dev/null 2>&1

# Stop cpulimit.service
sudo systemctl stop cpulimit.service > /dev/null 2>&1

# Remove cpulimit.service
sudo rm -rf /etc/systemd/system/cpulimit.service > /dev/null 2>&1

# Remove cpulimit.sh
sudo rm -rf /usr/local/bin/cpulimit.sh > /dev/null 2>&1

# Remove /etc/cpulimit
sudo rm -rf /etc/cpulimit > /dev/null 2>&1

# Restart systemd daemon
sudo systemctl daemon-reload > /dev/null 2>&1

printf "\nCompleted cpulimit uninstallation.\n\n"