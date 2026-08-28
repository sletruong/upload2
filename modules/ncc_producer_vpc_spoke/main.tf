# NCC PRODUCER VPC spoke (fabric): exports a PSA-peered producer network's
# ranges into the hub via the consumer VPC it peers with. Requires the PSA
# peering to exist on the linked VPC.
# ⚠ Field-name warning: include/exclude_export_ranges filter what this
# spoke EXPORTS to the hub — not to be confused with the hybrid spokes'
# include_import_ranges, which filters hub-table IMPORTS.

resource "google_network_connectivity_spoke" "spoke" {
  project     = var.project_id
  name        = var.name
  location    = "global"
  hub         = var.hub
  group       = var.group
  description = var.description
  labels      = var.labels

  linked_producer_vpc_network {
    network               = var.network
    peering               = var.peering
    include_export_ranges = length(var.include_export_ranges) > 0 ? var.include_export_ranges : null
    exclude_export_ranges = length(var.exclude_export_ranges) > 0 ? var.exclude_export_ranges : null
  }
}
