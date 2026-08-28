output "id" {
  description = "Hub id/URI (projects/*/locations/global/hubs/*) — what spokes reference."
  value       = google_network_connectivity_hub.hub.id
}

output "name" {
  description = "Hub name."
  value       = google_network_connectivity_hub.hub.name
}

output "unique_id" {
  description = "Server-generated unique id."
  value       = google_network_connectivity_hub.hub.unique_id
}

output "groups" {
  description = "Managed auto-accept groups keyed by group name (default/center/edge)."
  value       = { for k, g in google_network_connectivity_group.group : k => g.id }
}

output "summary" {
  description = "Condensed facts for cross-stage tooling (published to outputs.json by the stage root)."
  value = {
    id       = google_network_connectivity_hub.hub.id
    name     = google_network_connectivity_hub.hub.name
    project  = var.project_id
    topology = var.topology
    groups   = keys(google_network_connectivity_group.group)
  }
}
