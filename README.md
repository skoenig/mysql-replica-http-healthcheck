# MySQL Replica HTTP Healthcheck

This is a simple HTTP-based MySQL replica health check, consisting of a bash script, a systemd socket and a companion service. The check not only shows whether the database service is running or not, but also how much replication is lagging behind.

## Motivation
HTTP as the protocol for this health check is used to provide rich status information beyond simple connectivity checks, allowing validation of replication lag.

The health check is implemented using systemd socket activation, to provide a simple way to serve HTTP requests. This approach conserves system resources by starting the service only when needed, while systemd handles all low-level socket management. For some background on socket activation, see:
- http://0pointer.de/blog/projects/inetd.html
- https://mgdm.net/weblog/systemd-socket-activation/

The healthcheck script is also checking for the existence of a flag file to signal maintenance mode, e.g. when a replica needs to be replaced or updated: `touch /var/tmp/replica-maintenance`.

## Build VM Image
As prerequisites, you need [Hashicorp Packer](https://developer.hashicorp.com/packer) and [QEMU/KVM](https://www.qemu.org). This will allow you to build the image from the latest Debian locally:
```
packer build -var headless=false mysql.pkr.hcl
```
To base the build on a specific Debian version and name the resulting image like in the GitHub Actions pipeline, adapt the env vars in `.env` and run:
```
source .env
packer build -var headless=false $(scripts/create-tag.sh) .
```

## Demo Scenario
If you want to run the Percona MySQL distribution on GCP, you need to build your own image and provision VMs with it because this flavor is not available as a managed service like [Cloud SQL](https://cloud.google.com/sql).

The Terraform manifests in `infra/` create the infrastructure for this scenario within a Google Cloud Platform (GCP) project. They set up an internal application load balancer that polls port `9876` of the MySQL replica instance group to determine their health based on the returned HTTP status code.

To deploy this demo:

1. Create a GCP project.
2. Install Terraform or OpenTofu CLI.
3. Configure Terraform with your GCP credentials.
4. Update the `infra/variables.tf` file with your `project_id` and `region`.
5. Initialize / Plan / Apply Terraform: `cd infra/ && terraform init && terraform plan && terraform apply`
6. After the deployment completes, Terraform will output the load balancer's IP address (`lb_ip`) and DNS name (`lb_dns`).
7. You can then access the MySQL replicas through the load balancer's IP address on port `3306` from within your VPC, or resolve the DNS name from within the VPC.