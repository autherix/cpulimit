# cpulimit
A linux service that limits the cpu/ram usage by killing/pausing the high-consumption processes

## How it works?
- There is a service that runs every 20 seconds and checks the cpu/ram usage of the processes
- If the usage is higher than the limit, the process is killed/paused and a notification is sent to the user + a log is created inside the service log (when you run `journalctl -u cpulimit.service`)
- The service is enabled by default, so it will run on startup

## How to install?
- Clone the repo
- Run `sudo ./install.sh`

## How to uninstall?
- Run `sudo ./uninstall.sh`

## How to change the limit?
- Edit the configuration file `/etc/cpulimit.conf` and change the values of `cpu_limit` and `ram_limit` (in MB)

## How to change the interval?
- Edit the configuration file `/etc/cpulimit.conf` and change the value of `interval` (in seconds)

## How to change the notification title?
- Edit the configuration file `/etc/cpulimit.conf` and change the value of `notification_title`

## How to change the notification body?
- Edit the configuration file `/etc/cpulimit.conf` and change the value of `notification_body`

## How to check the status of the service?
- Run `sudo systemctl status cpulimit.service`
OR
- Run `service cpulimit status`
-> This way you can also see the logs of the service !

## How to start the service?
- Run `sudo systemctl start cpulimit.service`

## How to stop the service?
- Run `sudo systemctl stop cpulimit.service`