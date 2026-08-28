output "pairing_key" {
  description = "PARTNER: hand this to the service provider to complete pairing (null for DEDICATED)."
  value       = google_compute_interconnect_attachment.attachment.pairing_key
}

output "state" {
  description = "Attachment state (PARTNER sits PENDING_PARTNER until pairing completes)."
  value       = google_compute_interconnect_attachment.attachment.state
}

output "addressing" {
  description = "The session addressing (cloud/customer router IPs — pairing-derived for PARTNER)."
  value = {
    cloud    = google_compute_interconnect_attachment.attachment.cloud_router_ip_address
    customer = google_compute_interconnect_attachment.attachment.customer_router_ip_address
  }
}

output "spoke_state" {
  description = "NCC hybrid spoke state (null when no spoke declared)."
  value       = try(google_network_connectivity_spoke.spoke[0].state, null)
}
