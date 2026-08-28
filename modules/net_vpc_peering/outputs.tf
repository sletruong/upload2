output "state" {
  description = "Peering state: INACTIVE until the OTHER side declares its half."
  value       = google_compute_network_peering.peering.state
}

output "state_details" {
  description = "Human-readable state detail."
  value       = google_compute_network_peering.peering.state_details
}
