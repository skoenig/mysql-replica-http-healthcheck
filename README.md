# MySQL Replica HTTP Healthcheck

This repository contains the setup for a healthchecking MySQL replicas over HTTP. Application loadbalancers can use the HTTP status to monitor the replicas, to ensure that not only mysql is running and available, but also that the replication is no lagging to far behind the primary instance.

The setup consists of a simple bash script that acts as an HTTP server, a systemd socket and a companion service.
