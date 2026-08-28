output "peering" {
  description = "The servicenetworking peering name (what producer_vpc spokes reference implicitly)."
  value       = google_service_networking_connection.connection.peering
}

output "ranges" {
  description = "Reserved range name => CIDR."
  value       = { for k, r in google_compute_global_address.range : k => "${r.address}/${r.prefix_length}" }
}
