resource "google_compute_router" "router" {
  for_each = var.routers

  name    = each.key
  region  = each.value.region
  network = var.network_name
  project = var.project_id

  dynamic "bgp" {
    for_each = each.value.bgp_spoke.asn != null ? [1] : []
    content {

      asn               = each.value.bgp_spoke.asn
      advertise_mode    = each.value.bgp_spoke.advertise_mode
      advertised_groups = each.value.bgp_spoke.advertise_mode != "DEFAULT" ? each.value.bgp_spoke.advertised_groups : null

      dynamic "advertised_ip_ranges" {
        for_each = each.value.bgp_spoke.advertised_ip_ranges
        content {
          range       = advertised_ip_ranges.value.range
          description = lookup(advertised_ip_ranges.value, "description", null)
        }
      }
    }
  }
}

resource "google_compute_router_interface" "router_interface_primary" {
  for_each = merge([
    for router_id, router in var.routers : {
      for interface_id, interface in router.ncc_interfaces : format("%s-%s", router_id, format("nic%02d", interface_id)) => {
        router_name        = router_id
        bgp_spoke          = router.bgp_spoke
        region             = router.region
        interface_id       = interface_id
        private_ip_address = interface.ip_address
        subnetwork         = interface.subnetwork
        # subnetwork = one([
        #   for subnetwork_id, subnetwork in data.google_compute_subnetworks.subnetworks[router.region].subnetworks : subnetwork.self_link if
        # cidrhost(subnetwork.ip_cidr_range, 0) == cidrhost("${interface.ip_address}/${split("/", subnetwork.ip_cidr_range)[1]}", 0)])
      } if interface.redundant_interface == null
    }
  ]...)

  project = var.project_id

  name                = format("%s-%s", each.value.router_name, format("nic%02d", each.value.interface_id))
  router              = each.value.router_name
  region              = each.value.region
  private_ip_address  = each.value.private_ip_address
  subnetwork          = each.value.subnetwork
  redundant_interface = null

  depends_on = [google_compute_router.router]
}

resource "google_compute_router_interface" "router_interface_redundant" {
  for_each = merge([
    for router_id, router in var.routers : {
      for interface_id, interface in router.ncc_interfaces : format("%s-%s", router_id, format("nic%02d", interface_id)) => {
        router_name         = router_id
        bgp_spoke           = router.bgp_spoke
        region              = router.region
        interface_id        = interface_id
        redundant_interface = interface.redundant_interface != null ? format("%s-%s", router_id, format("nic%02d", interface.redundant_interface)) : null
        private_ip_address  = interface.ip_address
        subnetwork          = interface.subnetwork
      } if interface.redundant_interface != null
    }
  ]...)

  project = var.project_id

  name                = format("%s-%s", each.value.router_name, format("nic%02d", each.value.interface_id))
  router              = each.value.router_name
  region              = each.value.region
  private_ip_address  = each.value.private_ip_address
  subnetwork          = each.value.subnetwork
  redundant_interface = each.value.redundant_interface

  depends_on = [google_compute_router.router, google_compute_router_interface.router_interface_primary]
}


resource "google_compute_address" "address" {
  for_each = merge([
    for router_id, router in var.routers : {
      for idx in range(0, router.cloud_nat.external_nat_ip_count) : format("%s-nat-ip-%02d", router_id, idx) => router.region
  } if router.cloud_nat != {} && router.cloud_nat.external_nat_ip_count > 0 && length(router.cloud_nat.external_nat_ip_list) == 0]...)

  project = var.project_id
  name    = each.key
  region  = each.value
}

### Cloud Nat Logic
module "cloud_nat" {
  source = "../gcp_cloud_nat"
  # Iterate over var.routers (always known at plan/destroy time) rather than
  # google_compute_router.router (only known after apply), which caused
  # "Invalid for_each argument" during terraform destroy.
  # region comes from var.routers; network is var.network_name (same value
  # the router itself was created with on line 6).
  for_each = { for
    router_id,
    router in
    var.routers :
    router_id => router
    if(
      try(router.cloud_nat.external_nat_ip_dynamic, false) ||
      try(router.cloud_nat.external_nat_ip_count, 0) > 0 ||
      try(length(router.cloud_nat.external_nat_ip_list), 0) > 0
    )
  }

  name          = format("%s-nat", each.key)
  project_id    = var.project_id
  create_router = false

  region  = each.value.region
  network = var.network_name
  router  = each.key

  enable_dynamic_port_allocation      = each.value.cloud_nat.enable_dynamic_port_allocation
  enable_endpoint_independent_mapping = each.value.cloud_nat.enable_endpoint_independent_mapping
  icmp_idle_timeout_sec               = each.value.cloud_nat.icmp_idle_timeout_sec
  log_config_enable                   = each.value.cloud_nat.log_config_enable
  log_config_filter                   = each.value.cloud_nat.log_config_filter
  max_ports_per_vm                    = each.value.cloud_nat.max_ports_per_vm
  min_ports_per_vm                    = each.value.cloud_nat.min_ports_per_vm
  nat_ips = length(each.value.cloud_nat.external_nat_ip_list) > 0 ? each.value.cloud_nat.external_nat_ip_list : [
    for addr in google_compute_address.address : addr.self_link if startswith(addr.name, each.key)
  ]
  rules = each.value.cloud_nat.rules

  ##  ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, LIST_OF_SUBNETWORKS
  source_subnetwork_ip_ranges_to_nat = each.value.cloud_nat.source_subnetwork_ip_ranges_to_nat
  subnetworks                        = each.value.cloud_nat.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS" ? each.value.cloud_nat.subnetworks_to_nat_list : []
  tcp_established_idle_timeout_sec   = each.value.var_router.cloud_nat.tcp_established_idle_timeout_sec
  tcp_transitory_idle_timeout_sec    = each.value.var_router.cloud_nat.tcp_transitory_idle_timeout_sec
  udp_idle_timeout_sec               = each.value.var_router.cloud_nat.udp_idle_timeout_sec

}
