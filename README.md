# MySQL Replica HTTP Healthcheck

This is a simple HTTP-based MySQL replica health check, consisting of a bash script, a systemd socket and a companion service. The check not only shows whether the database service is running or not, but also how much replication is lagging behind.

## Motivation
HTTP as the protocol for this health check is used to provide rich status information beyond simple connectivity checks, allowing validation of replication lag.

The health check is implemented using systemd socket activation, to provide a simple way to serve HTTP requests.  This approach conserves system resources by starting the service only when needed, while systemd handles all low-level socket management. For some background on socket activation, see:
- http://0pointer.de/blog/projects/inetd.html
- https://mgdm.net/weblog/systemd-socket-activation/

## Build VM Image
As prerequisites, you need [Hashicorp Packer](https://developer.hashicorp.com/packer) and [QEMU/KVM](https://www.qemu.org). This will allow you to build the image locally:
```
packer build mysql.pkr.hcl
```

This is pretty useful for testing the build locally. For the actual cloud environment, the source block can then be replaced with something like this:
```
 source "googlecompute" "debian" {
   project_id   = "your-project-id"
   zone         = "your-zone"
   subnetwork   = "default"
   source_image = "debian-12-genericcloud-amd64"
   image_name   = "your-image-name"
   image_family = "your-image-family"
   ssh_username = "builder"
 }
```

## Usage
Set up an application load balancer to regularly poll port `9876` of the MySQL Replica instance group to determine their health based on the returned HTTP status code.

It is possible to create a flag file to signal maintenance mode, e.g. when a replica needs to be replaced or updated: `touch /var/tmp/replica-maintenance`.
