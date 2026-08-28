resource "google_network_connectivity_hub" "ncc_hub" {
  for_each = var.ncc_hubs

  name        = each.value.ncc_hub_name
  description = lookup(each.value, "description", "")
  project     = var.project_id
}
