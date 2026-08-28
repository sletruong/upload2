# NSI intercept PRODUCER side — deployment group + its zonal deployments.
#
# PROVIDER SHAPE (verified, google 7.x):
#   - deployment_group.location is "currently restricted to 'global'"
#   - deployment.location is a ZONE, and deployment.forwarding_rule is
#     REQUIRED (regional forwarding-rule path)
#   - the deployment carries NO network field; its VPC binding is
#     transitive through the group
#
# NSI ≠ Cloud NGFW firewall endpoints. This is packet INTERCEPT (your
# fleet, inline, can drop), not the Google-managed engine.

resource "google_network_security_intercept_deployment_group" "this" {
  project                       = var.project_id
  location                      = "global" # provider-restricted
  intercept_deployment_group_id = var.name
  network                       = var.network
  description                   = var.description
  labels                        = var.labels
}

resource "google_network_security_intercept_deployment" "this" {
  for_each = var.deployments

  project                 = var.project_id
  location                = each.value.zone # ZONAL — the only one
  intercept_deployment_id = each.key
  # looked up by key, NOT read from each.value — see the variable's note
  forwarding_rule            = var.deployment_forwarding_rules[each.key]
  intercept_deployment_group = google_network_security_intercept_deployment_group.this.id
  description                = each.value.description
  labels                     = var.labels
}
