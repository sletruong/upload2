output "id" { value = google_compute_forwarding_rule.this.id }
output "ip_address" {
  description = "The endpoint address clients target. For SWP this is the proxy URL host."
  value       = google_compute_forwarding_rule.this.ip_address
}
output "psc_connection_status" {
  description = "PENDING here means the producer's connection_preference is ACCEPT_MANUAL and this project has not been allowlisted — a silent no-connectivity state."
  value       = google_compute_forwarding_rule.this.psc_connection_status
}
