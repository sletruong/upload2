output "id" {
  description = "Subnet id (projects/*/regions/*/subnetworks/*)."
  value       = google_compute_subnetwork.subnet.id
}

output "self_link" {
  description = "Subnet self link."
  value       = google_compute_subnetwork.subnet.self_link
}

output "summary" {
  description = "Condensed facts for cross-stage tooling."
  value = {
    id               = google_compute_subnetwork.subnet.id
    name             = google_compute_subnetwork.subnet.name
    region           = google_compute_subnetwork.subnet.region
    ipv4_cidr        = google_compute_subnetwork.subnet.ip_cidr_range
    secondary_ranges = { for r in google_compute_subnetwork.subnet.secondary_ip_range : r.range_name => r.ip_cidr_range }
  }
}
