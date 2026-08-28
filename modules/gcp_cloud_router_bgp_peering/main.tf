# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer
resource "google_compute_router_peer" "router_peer" {
  for_each = { for k1, v1 in var.bgp_peering.peers : format("%s-peer-%s", coalesce(v1.cloud_router_name, var.bgp_peering.cloud_router_name),
    uuidv5("x500", join(",", [
      for k2, v2 in {
        INSTANCE_NAME           = var.bgp_peering.instance_name,
        CLOUD_ROUTER_NAME       = coalesce(v1.cloud_router_name, var.bgp_peering.cloud_router_name),
        CLOUD_ROUTER_NIC_NUMBER = coalesce(v1.cloud_router_nic_number, "UNKNOWN"),
        CLOUD_ROUTER_NIC_NAME   = coalesce(v1.cloud_router_nic_name, "UNKNOWN"),
  } : format("%s=%s", k2, v2) if v2 != "UNKNOWN"]))) => v1 }

  project = var.project_id
  name    = each.value.peer_name != null ? each.value.peer_name : substr(each.key, 0, 63)
  enable  = each.value.enable
  router  = coalesce(each.value.cloud_router_name, var.bgp_peering.cloud_router_name)
  region  = one(regex("^(.*)-.", var.bgp_peering.instance_zone))
  interface = each.value.cloud_router_nic_name != null ? each.value.cloud_router_nic_name : (
    format("%s-%s",
      coalesce(
        each.value.cloud_router_name,
        var.bgp_peering.cloud_router_name
      ),
      format("nic%02d", each.value.cloud_router_nic_number)
    )
  )

  peer_asn = var.bgp_peering.instance_asn

  advertise_mode    = coalesce(each.value.advertise_mode, var.bgp_peering.advertise_mode)
  advertised_groups = coalesce(each.value.advertise_mode, var.bgp_peering.advertise_mode) == "CUSTOM" ? coalesce(each.value.advertised_groups, var.bgp_peering.advertised_groups) : []

  dynamic "advertised_ip_ranges" {
    for_each = coalesce(each.value.advertise_mode, var.bgp_peering.advertise_mode) == "CUSTOM" ? coalesce(each.value.advertised_ip_ranges, var.bgp_peering.advertised_ip_ranges) : []
    content {
      range       = advertised_ip_ranges.value.range
      description = lookup(advertised_ip_ranges.value, "description", null)
    }
  }

  # router_appliance_instance = data.google_compute_instance.instance.self_link
  router_appliance_instance = var.bgp_peering.instance_self_link
  peer_ip_address           = var.bgp_peering.instance_address
  # peer_ip_address = data.google_compute_instance.instance.network_interface[one([
  #   for idx, value in data.google_compute_instance.instance.network_interface : idx if endswith(value.subnetwork, var.bgp_peering.subnetwork_name)
  # ])].network_ip
  advertised_route_priority = each.value.priority
}
