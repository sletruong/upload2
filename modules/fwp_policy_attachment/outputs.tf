output "id" {
  description = "Association id."
  value       = var.type == "global" ? google_compute_network_firewall_policy_association.global[0].id : google_compute_region_network_firewall_policy_association.regional[0].id
}
