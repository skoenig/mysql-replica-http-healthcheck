output "lb_ip" {
  value = google_compute_forwarding_rule.mysql_replica.ip_address
}

output "lb_dns" {
  value = google_compute_forwarding_rule.mysql_replica.service_name
}
