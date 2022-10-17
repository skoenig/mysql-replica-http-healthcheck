# MySQL Replica HTTP Healthcheck

This repository contains the setup for a healthchecking MySQL replicas over HTTP. Application loadbalancers can use the HTTP status to monitor the replicas, to ensure that not only mysql is running and available, but also that the replication is no lagging to far behind the primary instance.

The setup consists of a simple bash script that acts as an HTTP server, a systemd socket and a companion service.

## Installation
```
cp -v mysqlchk.sh /opt/mysqlchk.sh
cp -v mysqlchk@.service /etc/systemd/system
cp -v mysqlchk.socket /etc/systemd/system
systemctl enable --now mysqlchk.socket
```

Ensure that the user (by default 'prometheus') for the `mysqlchk` service has permissions to execute `SHOW SLAVE STATUS` on the local MySQL instance.

The healthcheck service will expose the status as port `9876`.
