# MySQL Replica HTTP Healthcheck

This is a simple HTTP-based MySQL replica health check, consisting of a bash script, a systemd socket and a companion service.

## Motivation
HTTP as the protocol for this health check is used to provide rich status information beyond simple connectivity checks, allowing validation of replication lag. Load balancers commonly work with HTTP health checks for intelligent traffic routing. Running the check as a separate service also maintains clean separation from the MySQL process while retaining full monitoring capabilities.

The health check is implemented using systemd socket activation, to provide an efficient and robust way to serve HTTP requests. This approach conserves system resources by starting the service only when needed, while systemd handles all low-level socket management. For some background on socket activation, see:
- http://0pointer.de/blog/projects/inetd.html
- https://mgdm.net/weblog/systemd-socket-activation/

## Installation
```
cp -v mysqlchk.sh /opt/mysqlchk.sh
cp -v mysqlchk@.service /etc/systemd/system
cp -v mysqlchk.socket /etc/systemd/system
systemctl enable --now mysqlchk.socket
```

Ensure that the user (by default 'prometheus') for the `mysqlchk` service has permissions to execute `SHOW SLAVE STATUS` on the local MySQL instance.

## Usage
Set up an application load balancer to regularly poll port `9876` of the MySQL Replica instance group to determine their health based on the returned HTTP status code.

It is possible to create a flag file to signal maintenance mode, e.g. when a replica needs to be replaced or updated: `touch /var/tmp/replica-maintenance`.
