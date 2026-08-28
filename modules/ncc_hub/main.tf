resource "google_network_connectivity_hub" "hub" {
  project         = var.project_id
  name            = var.name
  description     = var.description
  labels          = var.labels
  export_psc      = var.export_psc_routes
  preset_topology = upper(var.topology)
}

# GCP creates the topology's groups implicitly with the hub; a group RESOURCE
# is only needed to manage auto-accept - one per group with projects listed.
# Keys are REAL group names: default | center/edge | gateways/prod/
# non-prod/services (hybrid_inspection amendability verified on a live apply).
locals {
  auto_accept_groups = { for group, projects in var.auto_accept : group => projects if length(projects) > 0 }
}

resource "google_network_connectivity_group" "group" {
  for_each = local.auto_accept_groups

  project     = var.project_id
  hub         = google_network_connectivity_hub.hub.id
  name        = each.key
  description = "Auto-accept group ${each.key} for ${var.name}"

  auto_accept {
    auto_accept_projects = each.value
  }
}
