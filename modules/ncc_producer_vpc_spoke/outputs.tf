output "id" {
  description = "Spoke id."
  value       = google_network_connectivity_spoke.spoke.id
}

output "state" {
  description = "Spoke state (ACTIVE once the hub accepts it — auto_accept or admin approval)."
  value       = google_network_connectivity_spoke.spoke.state
}
