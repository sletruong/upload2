# PRIVATE Cloud NAT (type=PRIVATE): translation between private address
# spaces — NCC inter-VPC overlap (rules match nexthop.hub) and hybrid
# overlap. No address pool: rules allocate from PRIVATE_NAT-purpose subnets.
# type + LIST_OF_SUBNETWORKS are module opinions, never written in documents.

resource "google_compute_router_nat" "nat" {
  # google-beta: private NAT64 is GCP Preview (schema marks the field
  # x-gcp-beta); beta is a superset, GA fields behave identically
  provider = google-beta
  project  = var.project_id
  name     = var.name
  region   = var.region
  router   = var.router

  type                                 = "PRIVATE"
  source_subnetwork_ip_ranges_to_nat   = "LIST_OF_SUBNETWORKS"
  source_subnetwork_ip_ranges_to_nat64 = length(var.nat64_subnetworks) > 0 ? "LIST_OF_IPV6_SUBNETWORKS" : null
  enable_endpoint_independent_mapping  = false

  min_ports_per_vm               = var.min_ports_per_vm
  max_ports_per_vm               = var.max_ports_per_vm
  enable_dynamic_port_allocation = var.enable_dynamic_port_allocation

  icmp_idle_timeout_sec            = var.timeouts.icmp
  tcp_established_idle_timeout_sec = var.timeouts.tcp_established
  tcp_transitory_idle_timeout_sec  = var.timeouts.tcp_transitory
  tcp_time_wait_timeout_sec        = var.timeouts.tcp_time_wait
  udp_idle_timeout_sec             = var.timeouts.udp

  dynamic "subnetwork" {
    for_each = var.subnetworks
    content {
      name = subnetwork.value.self_link
      # ranges object -> the provider's two fields (the lexicon owns the
      # translation): null/all = ALL_IP_RANGES; else the stated union of
      # primary and named secondaries
      source_ip_ranges_to_nat = subnetwork.value.ranges == null ? ["ALL_IP_RANGES"] : (subnetwork.value.ranges.all == true ? ["ALL_IP_RANGES"] : concat(
        subnetwork.value.ranges.primary == true ? ["PRIMARY_IP_RANGE"] : [],
        length(subnetwork.value.ranges.secondaries) > 0 ? ["LIST_OF_SECONDARY_IP_RANGES"] : []
      ))
      secondary_ip_range_names = subnetwork.value.ranges == null ? [] : subnetwork.value.ranges.secondaries
    }
  }

  dynamic "nat64_subnetwork" {
    for_each = var.nat64_subnetworks
    content {
      name = nat64_subnetwork.value
    }
  }

  dynamic "rules" {
    for_each = var.rules
    content {
      rule_number = tonumber(rules.key)
      match       = rules.value.match
      description = rules.value.description
      action {
        source_nat_active_ranges = rules.value.active_ranges
        source_nat_drain_ranges  = rules.value.drain_ranges
      }
    }
  }

  dynamic "log_config" {
    for_each = var.logging.enabled ? [1] : []
    content {
      enable = true
      filter = var.logging.filter
    }
  }
}
