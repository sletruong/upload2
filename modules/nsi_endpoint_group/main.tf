# NSI CONSUMER-side endpoint group + its VPC associations.
#
# THE SPG IS NOT HERE. It is its own family —
# modules/nsi_security_profile_group — mirroring how Cloud NGFW SPGs work:
# DEFINED in their own family, REFERENCED where used. One SPG may serve
# several endpoint groups, so nesting it here misstated the arity.
#
# TYPE SELECTS THE RESOURCE FAMILY, not a field: intercept and mirroring are
# separate GCP resources. `count` picks one; the other is never created.
#
# PROVIDER SHAPE (verified):
#   - endpoint_group.location is global; it has NO network field
#   - association carries `network` (the CONSUMER VPC)
#   - intercept_endpoint_group_association_id is `optional` and EFFECTIVELY
#     REQUIRED — omitting it creates a PHANTOM under a server-side UUID
#     (`knowledge-base/nsi-operational-laws.md` law 3)

locals {
  is_mirror = var.type == "MIRROR"
}

resource "google_network_security_intercept_endpoint_group" "this" {
  count = local.is_mirror ? 0 : 1

  project                     = var.project_id
  location                    = "global"
  intercept_endpoint_group_id = var.name
  intercept_deployment_group  = var.deployment_group
  description                 = var.description
  labels                      = var.labels
}

resource "google_network_security_mirroring_endpoint_group" "this" {
  count = local.is_mirror ? 1 : 0

  project                     = var.project_id
  location                    = "global"
  mirroring_endpoint_group_id = var.name
  mirroring_deployment_group  = var.deployment_group
  description                 = var.description
  labels                      = var.labels
}

# ⚠ THE ASSOCIATION ID IS EFFECTIVELY REQUIRED. Omit it and the resource
# applies "successfully" into a PHANTOM: the id comes back with an empty
# final segment, every attribute reads null, and a later plan reports NO
# CHANGES because Terraform believes the object exists. `-refresh-only`
# does not reconcile it either. Verified on a live apply.
resource "google_network_security_intercept_endpoint_group_association" "this" {
  for_each = local.is_mirror ? {} : var.associations

  project                                 = var.project_id
  location                                = "global"
  intercept_endpoint_group_association_id = each.key
  intercept_endpoint_group                = google_network_security_intercept_endpoint_group.this[0].id
  network                                 = each.value
  labels                                  = var.labels
}

resource "google_network_security_mirroring_endpoint_group_association" "this" {
  for_each = local.is_mirror ? var.associations : {}

  project                                 = var.project_id
  location                                = "global"
  mirroring_endpoint_group_association_id = each.key
  mirroring_endpoint_group                = google_network_security_mirroring_endpoint_group.this[0].id
  network                                 = each.value
  labels                                  = var.labels
}
