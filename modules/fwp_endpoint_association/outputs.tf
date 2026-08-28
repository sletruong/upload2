output "id" {
  description = "Association id."
  value       = google_network_security_firewall_endpoint_association.association.id
}

output "state" {
  description = "Association state (endpoint attach is asynchronous — watch for ACTIVE)."
  value       = google_network_security_firewall_endpoint_association.association.state
}
