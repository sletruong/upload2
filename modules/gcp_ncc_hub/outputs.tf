output "ncc_hub_ids" {
  value       = { for k, v in google_network_connectivity_hub.ncc_hub : k => v.id }
  description = "IDs of the NCC Hubs"
}

output "ncc_hub_names" {
  value       = { for k, v in google_network_connectivity_hub.ncc_hub : k => v.name }
  description = "Names of the NCC Hubs"
}