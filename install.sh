#!/usr/bin/env bash

# Get current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Uninstall first
source $DIR/uninstall.sh

# Copy $DIR/cpulimit.service to /etc/systemd/system/cpulimit.service
sudo cp $DIR/cpulimit.service /etc/systemd/system/cpulimit.service

# Copy $DIR/cpulimit.sh to /usr/local/bin/cpulimit.sh
sudo cp $DIR/cpulimit.sh /usr/local/bin/cpulimit.sh

# make directory /etc/cpulimit
sudo mkdir /etc/cpulimit > /dev/null 2>&1

# Copy $DIR/cpulimit.conf to /etc/cpulimit/cpulimit.conf
sudo cp $DIR/cpulimit.conf /etc/cpulimit/cpulimit.conf

# Restart systemd daemon, enable cpulimit.service to run on startup
sudo systemctl daemon-reload
sudo systemctl enable cpulimit.service

# Start cpulimit.service
sudo systemctl start cpulimit.service

# restart cpulimit.service
sudo systemctl restart cpulimit.service

printf "\nCompleted cpulimit installation.\n\n"