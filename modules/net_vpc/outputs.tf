output "id" {
  description = "Network id (projects/*/global/networks/*)."
  value       = google_compute_network.vpc.id
}

output "name" {
  description = "Network name."
  value       = google_compute_network.vpc.name
}

output "self_link" {
  description = "Network self link."
  value       = google_compute_network.vpc.self_link
}

output "summary" {
  description = "Condensed facts for cross-stage tooling (published to outputs.json by the stage root)."
  value = {
    id           = google_compute_network.vpc.id
    name         = google_compute_network.vpc.name
    self_link    = google_compute_network.vpc.self_link
    project      = var.project_id
    routing_mode = var.routing_mode
    mtu          = var.mtu
  }
}
