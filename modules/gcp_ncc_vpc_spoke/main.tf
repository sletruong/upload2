resource "google_network_connectivity_spoke" "ncc_spoke" {
  project  = var.project_id
  name     = var.spoke_name
  hub      = var.hub_name
  location = "global"

  linked_vpc_network {
    uri                   = "projects/${var.project_id}/global/networks/${var.network_name}"
    exclude_export_ranges = var.exclude_export_ranges
    include_export_ranges = []
  }
}
