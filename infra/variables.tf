variable "project_id" {
  description = "GCP project ID to deploy in."
  type        = string

}
variable "region" {
  description = "GCP region to deploy in."
  type        = string
}

variable "instance_num" {
  description = "Number of replica instances."
  default     = 1
}

variable "images" {
  description = <<-EOT
    Names of images to be used for replicas. Normally, this should be only one.

    Defining multiple images is useful to roll over to a new version without downtime.
  EOT
  type        = list(string)
  default = [
    "mysql-debian-11-57-20250801-2191-44fde156",
  ]
}

variable "machine_type" {
  description = "Machine type to be used for replica instances."
  default     = "e2-micro"
}

variable "source_ips" {
  description = "Source IP range from where replicas are accessed."
  default     = ["172.17.0.0/16"]
}
