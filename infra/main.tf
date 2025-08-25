terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = "${var.region}-b"
}

locals {
  # This creates a map of unique-ish strings (substring of hashed image name + number)
  # to image names. The key of the resulting map will be used for stable instance naming.
  # For example, with instance_num = 3 and
  # images = [
  #  "mysql-debian-11-57-20250801-2191-a85ada5f",
  #  "mysql-debian-11-57-20250801-2191-44fde156",
  # ]
  # it will produce:
  # {
  #   "2826" = "mysql-debian-11-57-20250801-2191-a85ada5f"
  #   "647a" = "mysql-debian-11-57-20250801-2191-44fde156"
  #   "83bc" = "mysql-debian-11-57-20250801-2191-a85ada5f"
  #   "853d" = "mysql-debian-11-57-20250801-2191-44fde156"
  #   "e985" = "mysql-debian-11-57-20250801-2191-a85ada5f"
  #   "f125" = "mysql-debian-11-57-20250801-2191-44fde156"
  # }
  instances = {
    for pair in setproduct(var.images, range(var.instance_num)) :
    substr(sha256("${pair[0]}-${pair[1]}"), 0, 4) => pair[0]
  }
}

resource "google_project_service" "compute_engine" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}
data "google_compute_image" "mysql_replica" {
  depends_on = [google_project_service.compute_engine]
  for_each   = toset(var.images)
  name       = each.value
}

resource "google_compute_network" "primary" {
  depends_on              = [google_project_service.compute_engine]
  name                    = "test-infra"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "primary" {
  name                     = "test-infra-${var.region}"
  ip_cidr_range            = "10.32.0.0/16"
  network                  = google_compute_network.primary.self_link
  region                   = var.region
  private_ip_google_access = true
}

resource "google_compute_instance_template" "mysql_replica" {
  for_each     = data.google_compute_image.mysql_replica
  name_prefix  = "mysql-replica-"
  machine_type = var.machine_type

  disk {
    source_image = data.google_compute_image.mysql_replica[each.key].id
    boot         = true
    disk_type    = "pd-standard"
    disk_size_gb = 500
  }

  tags = ["mysql-replica"]

  network_interface {
    subnetwork = google_compute_subnetwork.primary.name
    access_config {
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_from_template" "mysql_replica" {
  for_each                 = local.instances
  name                     = "mysql-replica-${each.key}"
  source_instance_template = google_compute_instance_template.mysql_replica[each.value].id
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group" "mysql_replica" {
  name = "mysql-replica-group"
  instances = [for instance in google_compute_instance_from_template.mysql_replica : instance.self_link]
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_forwarding_rule" "mysql_replica" {
  name                  = "mysql-replica"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  ports                 = ["3306"]
  service_label         = "mysql"
  network               = google_compute_network.primary.name
  subnetwork            = google_compute_subnetwork.primary.name
  backend_service       = google_compute_region_backend_service.mysql_replica.self_link
}

resource "google_compute_region_backend_service" "mysql_replica" {
  name          = "mysql-replica"
  region        = var.region
  network       = google_compute_network.primary.name
  health_checks = concat(google_compute_health_check.mysql_replica_http_hc.*.self_link)
  backend {
    group          = google_compute_instance_group.mysql_replica.self_link
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_health_check" "mysql_replica_http_hc" {
  name       = "mysql-replica-http-hc"
  depends_on = [google_project_service.compute_engine]

  http_health_check {
    port     = 9876
    response = "Replica OK"
  }

  timeout_sec         = 5
  check_interval_sec  = 15
  unhealthy_threshold = 3
}

resource "google_compute_firewall" "mysql_replica_allow_ilb" {
  name    = "mysql-replica-allow-ilb"
  network = google_compute_network.primary.name

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = var.source_ips
  target_tags   = ["mysql-replica"]
}

resource "google_compute_firewall" "mysql_replica_allow_hc" {
  name    = "mysql-replica-allow-healthcheck"
  network = google_compute_network.primary.name

  allow {
    protocol = "tcp"
    ports    = ["9876"]
  }

  # https://cloud.google.com/load-balancing/docs/firewall-rules
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  direction     = "INGRESS"
  target_tags   = ["mysql-replica"]
}

resource "google_compute_firewall" "mysql_replica_allow_ssh" {
  name        = "mysql-replica-allow-ssh"
  description = "SSH access via IAP for management and debugging"
  network     = google_compute_network.primary.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["mysql-replica"]
}
