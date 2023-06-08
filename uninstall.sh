#!/usr/bin/env bash

# Disable cpulimit.service
sudo systemctl disable cpulimit.service

# Stop cpulimit.service
sudo systemctl stop cpulimit.service

# Remove cpulimit.service
sudo rm /etc/systemd/system/cpulimit.service

# Remove cpulimit.sh
sudo rm /usr/local/bin/cpulimit.sh

# Remove /etc/cpulimit
sudo rm -rf /etc/cpulimit

# Restart systemd daemon
sudo systemctl daemon-reload

printf "\nCompleted cpulimit uninstallation.\n\n"