resource "google_compute_network" "vpc" {
  # BGP best-path selection (STANDARD unlocks MED/inter-region behavior)
  bgp_best_path_selection_mode = var.bgp_best_path_selection_mode
  bgp_always_compare_med       = var.bgp_always_compare_med
  bgp_inter_region_cost        = var.bgp_inter_region_cost

  project     = var.project_id
  name        = var.name
  description = var.description

  auto_create_subnetworks                   = var.auto_create_subnetworks
  routing_mode                              = var.routing_mode
  mtu                                       = var.mtu
  delete_default_routes_on_create           = var.delete_default_internet_gateway_routes
  enable_ula_internal_ipv6                  = var.enable_ula_internal_ipv6
  internal_ipv6_range                       = var.internal_ipv6_range
  network_firewall_policy_enforcement_order = var.firewall_policy_enforcement_order
}
