resource "google_network_connectivity_spoke" "ncc_spoke" {
  project = var.project_id

  name     = var.ncc_appliance_spoke.spoke_name
  hub      = var.ncc_appliance_spoke.hub_name
  location = var.region

  linked_router_appliance_instances {
    site_to_site_data_transfer = var.ncc_appliance_spoke.enable_site_data_transfer
    include_import_ranges      = ["ALL_IPV4_RANGES"]

    dynamic "instances" {
      for_each = var.ncc_appliance_spoke.instances
      content {
        virtual_machine = instances.value["self_link"]
        ip_address      = instances.value["ip_address"]
      }
    }
  }
}
