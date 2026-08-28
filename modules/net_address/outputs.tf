output "address" {
  description = "The IP value — the read-back for GCP-assigned EXTERNAL addresses."
  value       = var.scope == "global" ? google_compute_global_address.global[0].address : google_compute_address.regional[0].address
}

output "self_link" {
  description = "Address self link — what NAT nat_addresses and future consumers reference."
  value       = var.scope == "global" ? google_compute_global_address.global[0].self_link : google_compute_address.regional[0].self_link
}

output "name" {
  description = "Rendered name (the family reference surface)."
  value       = var.name
}
