# NCC VPC spoke (fabric): attaches this stage's VPC to a tier-0 hub by full
# URI (names-as-contract — no remote state). The VPC self-link reference is
# the ordering edge; the hub must exist (stage 0 applies first).
# ⚠ Field-name warning: the provider field is include_EXPORT_ranges — it
# filters what this spoke exports to the hub. Do not confuse it with the
# hybrid spokes' include_import_ranges, which filters hub-table IMPORTS.

resource "google_network_connectivity_spoke" "spoke" {
  project     = var.project_id
  name        = var.name
  location    = "global"
  hub         = var.hub
  group       = var.group
  description = var.description
  labels      = var.labels

  linked_vpc_network {
    uri                   = var.network
    include_export_ranges = length(var.include_export_ranges) > 0 ? var.include_export_ranges : null
    exclude_export_ranges = length(var.exclude_export_ranges) > 0 ? var.exclude_export_ranges : null
  }
}
