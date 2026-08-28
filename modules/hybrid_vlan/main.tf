# Interconnect VLAN attachment (tier 3): attachment + FAMILY-TYPED BGP
# sessions, each owning its 1:1 router interface. PARTNER addressing derives
# from the pairing flow (v4 cloud/customer router IPs); v6 and Automatic
# modes leave addressing to GCP.

resource "google_compute_interconnect_attachment" "attachment" {
  stack_type = var.stack_type
  project    = var.project_id
  name       = var.name
  region     = var.region
  router     = "projects/${var.project_id}/regions/${var.region}/routers/${var.router}"
  type       = var.type

  interconnect             = var.interconnect
  edge_availability_domain = var.edge_availability_domain
  bandwidth                = var.bandwidth
  vlan_tag8021q            = var.vlan_tag
  admin_enabled            = var.admin_enabled
}

resource "google_compute_router_interface" "session" {
  for_each = var.bgp_sessions

  project = var.project_id
  region  = var.region
  router  = var.router
  name    = each.value.interface_name

  # v4 PARTNER: pairing-assigned; DEDICATED manual; v6/auto: GCP allocates
  ip_range = each.key == "ipv4" ? (
    each.value.local_address_range != null ? each.value.local_address_range : try(google_compute_interconnect_attachment.attachment.cloud_router_ip_address, null)
  ) : each.value.local_address_range
  ip_version              = each.key == "ipv6" ? "IPV6" : null
  interconnect_attachment = google_compute_interconnect_attachment.attachment.name
}

resource "google_compute_router_peer" "session" {
  for_each = var.bgp_sessions

  project = var.project_id
  region  = var.region
  router  = var.router
  name    = each.value.name

  interface = google_compute_router_interface.session[each.key].name
  peer_asn  = each.value.peer_asn
  peer_ip_address = each.key == "ipv4" ? (
    each.value.peer_address != null ? each.value.peer_address : try(split("/", google_compute_interconnect_attachment.attachment.customer_router_ip_address)[0], null)
  ) : each.value.peer_address

  advertised_route_priority = each.value.advertised_route_priority

  # Per-session advertisement override (CUSTOM if present, else inherit router).
  advertise_mode    = try(each.value.advertised, null) != null ? "CUSTOM" : null
  advertised_groups = try(each.value.advertised.groups, null)
  dynamic "advertised_ip_ranges" {
    for_each = try(each.value.advertised.ip_ranges, [])
    content {
      range       = advertised_ip_ranges.value.range
      description = try(advertised_ip_ranges.value.description, null)
    }
  }
  # Custom-learned routes toward this session.
  dynamic "custom_learned_ip_ranges" {
    for_each = try(each.value.custom_learned_routes.ranges, [])
    content {
      range = custom_learned_ip_ranges.value
    }
  }
  custom_learned_route_priority      = length(try(each.value.custom_learned_routes.ranges, [])) == 0 ? null : (try(each.value.custom_learned_routes.priority, null) != null && try(each.value.custom_learned_routes.priority, 1) != 0 ? each.value.custom_learned_routes.priority : null)
  zero_custom_learned_route_priority = length(try(each.value.custom_learned_routes.ranges, [])) == 0 ? null : (try(each.value.custom_learned_routes.priority, 1) == 0)

  import_policies = each.value.import_policies
  export_policies = each.value.export_policies
  # v6-interface peers require enable_ipv6 — the API rejects them without it (400, verified live)
  enable_ipv6 = each.key == "ipv6" || each.value.exchange_ipv6
  enable_ipv4 = each.value.exchange_ipv4 ? true : null
  enable      = each.value.enabled # exists-but-inert: direct map
}

resource "google_network_connectivity_spoke" "spoke" {
  count = var.ncc_spoke != null ? 1 : 0

  project  = var.project_id
  name     = var.ncc_spoke.name
  location = var.region
  hub      = var.ncc_spoke.hub
  group    = var.ncc_spoke.group

  linked_interconnect_attachments {
    uris                       = [google_compute_interconnect_attachment.attachment.self_link]
    site_to_site_data_transfer = var.ncc_spoke.site_to_site_data_transfer
    include_import_ranges      = var.ncc_spoke.include_import_ranges
  }
}
