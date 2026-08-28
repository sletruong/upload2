# Cloud NAT (fabric): nests under its router — the router is its own module,
# and every name is EXPLICIT (no generated suffixes; the naming contract).
# Allocation opinion: nat_addresses empty = AUTO_ONLY, non-empty = MANUAL_ONLY.

# Explicit-named created addresses: one address per entry.
resource "google_compute_address" "static" {
  for_each = { for ip in var.static_addresses : ip.name => ip }

  project = var.project_id
  name    = each.value.name
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  project = var.project_id
  name    = var.name
  region  = var.region
  router  = var.router

  nat_ip_allocate_option = length(var.nat_addresses) + length(var.static_addresses) > 0 ? "MANUAL_ONLY" : "AUTO_ONLY"

  # NAT64: the list IS the statement — mode derived from presence
  source_subnetwork_ip_ranges_to_nat64 = length(var.nat64_subnetworks) > 0 ? "LIST_OF_IPV6_SUBNETWORKS" : null
  # mixing created + brought is legal — each entry owns its lifecycle
  nat_ips                            = concat([for ip in var.static_addresses : google_compute_address.static[ip.name].self_link], var.nat_addresses)
  source_subnetwork_ip_ranges_to_nat = var.source_subnetwork_ip_ranges_to_nat

  min_ports_per_vm                    = var.min_ports_per_vm
  max_ports_per_vm                    = var.max_ports_per_vm
  enable_dynamic_port_allocation      = var.enable_dynamic_port_allocation
  enable_endpoint_independent_mapping = var.enable_endpoint_independent_mapping
  # null = provider default (ENDPOINT_TYPE_VM). Changing this REPLACES the
  # gateway, so it is a create-time decision, not a day-2 knob.
  endpoint_types = var.endpoint_types

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

  # Rules keyed by number; action IPs resolve static_addresses names -> self links
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
        source_nat_active_ips = [for ip in rules.value.active_addresses : can(regex("^(https://|projects/)", ip)) ? ip : google_compute_address.static[ip].self_link]
        source_nat_drain_ips  = [for ip in rules.value.drain_addresses : can(regex("^(https://|projects/)", ip)) ? ip : google_compute_address.static[ip].self_link]
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
