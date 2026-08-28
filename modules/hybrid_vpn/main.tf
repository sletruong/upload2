# HA VPN connection (tier 3): gateway + external peer gateways + tunnels,
# each tunnel carrying FAMILY-TYPED BGP sessions (ipv4/ipv6/both — the
# console permutations), each session owning its 1:1 router interface.
# Automatic addressing = omit local_address_range/peer_address (GCP allocates:
# v4 from 169.254.0.0/16, v6 from fdff:1::/64). Sessions subscribe to the
# fabric router's route-policy library by name.

locals {
  tunnels = merge([
    for pi, p in var.external_peers : {
      for t in p.tunnels : t.name => merge(t, { peer_name = p.name })
    }
  ]...)
  generated = { for tn, t in local.tunnels : tn => t if t.shared_secret.generate }

  # (tunnel, family) -> session
  sessions = merge([
    for tn, t in local.tunnels : {
      for fam, ss in t.bgp_sessions : "${tn}:${fam}" => merge(ss, {
        tunnel = tn
        family = fam
      })
    }
  ]...)
}

resource "google_compute_ha_vpn_gateway" "gateway" {
  stack_type = var.stack_type
  project    = var.project_id
  name       = var.name
  region     = var.region
  network    = var.network
}

resource "google_compute_external_vpn_gateway" "peer" {
  for_each = { for p in var.external_peers : p.name => p }

  project         = var.project_id
  name            = each.key
  description     = each.value.description
  redundancy_type = each.value.redundancy_type

  dynamic "interface" {
    for_each = { for idx, i in each.value.interfaces : idx => i }
    content {
      id           = interface.key
      ip_address   = interface.value.ipv4_address
      ipv6_address = interface.value.ipv6_address
    }
  }
}


# Secret Manager PSK refs (shared_secret.secret): the ONE justified data
# lookup in this module — deployment NEEDS the PSK value
# (design_and_backlog/DESIGN-DOCTRINE.md). Short name = doc's project +
# latest; full path honored; "/versions/N" split out.
locals {
  all_tunnels_by_family = {
    ext  = local.tunnels
    near = local.gcp_tunnels
    solo = local.gcp_solo_tunnels
  }
  secret_refs = merge([
    for fam, m in local.all_tunnels_by_family : {
      for tn, t in m : "${fam}/${tn}" => t.shared_secret.secret
      if try(t.shared_secret.secret, null) != null
    }
  ]...)
}

data "google_secret_manager_secret_version" "psk" {
  for_each = local.secret_refs
  project  = startswith(each.value, "projects/") ? null : var.project_id
  secret   = length(split("/versions/", each.value)) > 1 ? split("/versions/", each.value)[0] : each.value
  version  = length(split("/versions/", each.value)) > 1 ? split("/versions/", each.value)[1] : "latest"
}

resource "random_password" "psk" {
  for_each = local.generated

  length  = 32
  special = false
}

resource "google_compute_vpn_tunnel" "tunnel" {
  for_each = local.tunnels

  project = var.project_id
  name    = each.key
  region  = var.region

  vpn_gateway           = google_compute_ha_vpn_gateway.gateway.id
  vpn_gateway_interface = each.value.gateway_interface

  peer_external_gateway           = google_compute_external_vpn_gateway.peer[each.value.peer_name].id
  peer_external_gateway_interface = each.value.peer_interface

  router        = var.router
  ike_version   = each.value.ike_version
  shared_secret = each.value.shared_secret.generate ? random_password.psk[each.key].result : (try(each.value.shared_secret.secret, null) != null ? data.google_secret_manager_secret_version.psk["ext/${each.key}"].secret_data : each.value.shared_secret.value)
}

# one interface + one peer per (tunnel, family) session
resource "google_compute_router_interface" "session" {
  for_each = local.sessions

  project    = var.project_id
  region     = var.region
  router     = var.router
  name       = each.value.interface_name
  ip_range   = each.value.local_address_range # null = Automatic allocation
  ip_version = each.value.family == "ipv6" ? "IPV6" : null
  vpn_tunnel = google_compute_vpn_tunnel.tunnel[each.value.tunnel].name
}

resource "google_compute_router_peer" "session" {
  for_each = local.sessions

  project = var.project_id
  region  = var.region
  router  = var.router
  name    = each.value.name

  interface       = google_compute_router_interface.session[each.key].name
  peer_ip_address = each.value.peer_address # null = Automatic allocation
  # The API rejects a peer on an IPv6 interface that has IPv6 disabled
  # (400, verified live) — the family key IS the statement; module owns the wire
  enable_ipv6 = each.value.family == "ipv6" || each.value.exchange_ipv6
  # MP mirror: v4 exchange over a native v6 session (GCP allocates v4 nexthops)
  enable_ipv4 = each.value.exchange_ipv4 ? true : null
  # exists-but-inert: GCP's positive field, direct map (no polarity flip)
  enable   = each.value.enabled
  peer_asn = each.value.peer_asn

  advertised_route_priority = each.value.advertised_route_priority

  # Per-session advertisement OVERRIDE: present → CUSTOM for this session
  # (overrides the router-level bgp.advertised); absent → inherit the router.
  advertise_mode    = try(each.value.advertised, null) != null ? "CUSTOM" : null
  advertised_groups = try(each.value.advertised.groups, null)
  dynamic "advertised_ip_ranges" {
    for_each = try(each.value.advertised.ip_ranges, [])
    content {
      range       = advertised_ip_ranges.value.range
      description = try(advertised_ip_ranges.value.description, null)
    }
  }

  # Custom-learned routes: install the given prefixes toward this session as if
  # learned from the peer. priority null → GCP default 100; 0 needs the zero flag.
  # When NO ranges: BOTH priority and zero-flag go null (not zero:false) —
  # verified live: the provider rejects the in-place REMOVAL transition
  # ("zero_custom_learned_route_priority false → priority cannot be 0"). Removing
  # a live custom-learned config needs `terraform apply -replace` on the peer.
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
}

resource "google_network_connectivity_spoke" "spoke" {
  count = var.ncc_spoke != null ? 1 : 0

  project  = var.project_id
  name     = var.ncc_spoke.name
  location = var.region
  hub      = var.ncc_spoke.hub
  group    = var.ncc_spoke.group

  linked_vpn_tunnels {
    uris = concat(
      [for tn, t in google_compute_vpn_tunnel.tunnel : t.self_link],
      [for tn, t in google_compute_vpn_tunnel.gcp_near : t.self_link],
      [for tn, t in google_compute_vpn_tunnel.gcp_solo : t.self_link],
    )
    site_to_site_data_transfer = var.ncc_spoke.site_to_site_data_transfer
    include_import_ranges      = var.ncc_spoke.include_import_ranges
  }
}

# ── GCP<->GCP peer PAIRS: ONE entry builds BOTH sides ─────────────────────────
locals {
  gcp_tunnels = merge([
    for p in var.gcp_peer_pairs : {
      for t in p.tunnels : t.name => merge(t, {
        peer_name    = p.name
        peer_gateway = p.peer_gateway
        peer_router  = p.peer_router
        peer_project = coalesce(p.peer_project_id, var.project_id)
        local_asn    = p.local_asn
        peer_asn     = p.peer_asn
      })
    }
  ]...)
  gcp_generated = { for tn, t in local.gcp_tunnels : tn => t if t.shared_secret.generate }

  gcp_sessions = merge([
    for tn, t in local.gcp_tunnels : {
      for fam, ss in t.bgp_sessions : "${tn}:${fam}" => merge(ss, {
        tunnel = tn
        family = fam
      })
    }
  ]...)
  # far side mirrors: local range <-> peer address swap (prefix carried over)
  gcp_far_sessions = {
    for k, ss in local.gcp_sessions : k => merge(ss, {
      far_local_range = "${ss.peer_address}/${split("/", ss.local_address_range)[1]}"
      far_peer_ip     = split("/", ss.local_address_range)[0]
    })
  }
}

resource "random_password" "gcp_psk" {
  for_each = local.gcp_generated
  length   = 32
  special  = false
}

resource "google_compute_vpn_tunnel" "gcp_near" {
  for_each = local.gcp_tunnels

  project               = var.project_id
  name                  = each.key
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gateway.id
  peer_gcp_gateway      = each.value.peer_gateway
  vpn_gateway_interface = each.value.gateway_interface
  router                = var.router
  ike_version           = each.value.ike_version
  shared_secret         = each.value.shared_secret.generate ? random_password.gcp_psk[each.key].result : (try(each.value.shared_secret.secret, null) != null ? data.google_secret_manager_secret_version.psk["near/${each.key}"].secret_data : each.value.shared_secret.value)
}

resource "google_compute_vpn_tunnel" "gcp_far" {
  for_each = local.gcp_tunnels

  project               = each.value.peer_project
  name                  = each.value.peer_tunnel_name
  region                = var.region
  vpn_gateway           = each.value.peer_gateway
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gateway.id
  vpn_gateway_interface = each.value.gateway_interface # i<->i pairing law
  router                = "projects/${each.value.peer_project}/regions/${var.region}/routers/${each.value.peer_router}"
  ike_version           = each.value.ike_version
  shared_secret         = each.value.shared_secret.generate ? random_password.gcp_psk[each.key].result : (try(each.value.shared_secret.secret, null) != null ? data.google_secret_manager_secret_version.psk["near/${each.key}"].secret_data : each.value.shared_secret.value)
}

resource "google_compute_router_interface" "gcp_near" {
  for_each = local.gcp_sessions

  project    = var.project_id
  region     = var.region
  router     = var.router
  name       = each.value.interface_name
  ip_range   = each.value.local_address_range
  ip_version = each.value.family == "ipv6" ? "IPV6" : null
  vpn_tunnel = google_compute_vpn_tunnel.gcp_near[each.value.tunnel].name
}

resource "google_compute_router_peer" "gcp_near" {
  for_each = local.gcp_sessions

  project         = var.project_id
  region          = var.region
  router          = var.router
  name            = each.value.name
  interface       = google_compute_router_interface.gcp_near[each.key].name
  peer_ip_address = each.value.peer_address
  peer_asn        = local.gcp_tunnels[each.value.tunnel].peer_asn
  # v6-interface peers require enable_ipv6 — the API rejects them without it (400, verified live)
  enable_ipv6               = each.value.family == "ipv6"
  enable                    = each.value.enabled
  advertised_route_priority = each.value.advertised_route_priority

  advertise_mode    = try(each.value.advertised, null) != null ? "CUSTOM" : null
  advertised_groups = try(each.value.advertised.groups, null)
  dynamic "advertised_ip_ranges" {
    for_each = try(each.value.advertised.ip_ranges, [])
    content {
      range       = advertised_ip_ranges.value.range
      description = try(advertised_ip_ranges.value.description, null)
    }
  }

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
}

resource "google_compute_router_interface" "gcp_far" {
  for_each = local.gcp_far_sessions

  project    = local.gcp_tunnels[each.value.tunnel].peer_project
  region     = var.region
  router     = local.gcp_tunnels[each.value.tunnel].peer_router
  name       = each.value.peer_interface_name
  ip_range   = each.value.far_local_range
  ip_version = each.value.family == "ipv6" ? "IPV6" : null
  vpn_tunnel = google_compute_vpn_tunnel.gcp_far[each.value.tunnel].name
}

resource "google_compute_router_peer" "gcp_far" {
  for_each = local.gcp_far_sessions

  project         = local.gcp_tunnels[each.value.tunnel].peer_project
  region          = var.region
  router          = local.gcp_tunnels[each.value.tunnel].peer_router
  name            = each.value.peer_session_name
  interface       = google_compute_router_interface.gcp_far[each.key].name
  peer_ip_address = each.value.far_peer_ip
  peer_asn        = local.gcp_tunnels[each.value.tunnel].local_asn
  enable_ipv6     = each.value.family == "ipv6"
  enable          = each.value.enabled
  # custom_learned_routes is DIRECTIONAL and declared from the NEAR side's
  # perspective (like local_asn/peer_asn) — it applies to the near peer only.
  # The far mirror does NOT custom-learn (symmetric learning would be a
  # different, usually-unwanted intent; declare the far side's own doc for it).
}

# ── GCP<->GCP ONE-SIDE peers (the peering analog): near side only ────────
locals {
  gcp_solo_tunnels = merge([
    for p in var.gcp_peers : {
      for t in p.tunnels : t.name => merge(t, { peer_gateway = p.peer_gateway })
    }
  ]...)
  gcp_solo_generated = { for tn, t in local.gcp_solo_tunnels : tn => t if t.shared_secret.generate }
  gcp_solo_sessions = merge([
    for tn, t in local.gcp_solo_tunnels : {
      for fam, ss in t.bgp_sessions : "${tn}:${fam}" => merge(ss, { tunnel = tn, family = fam })
    }
  ]...)
}

resource "random_password" "gcp_solo_psk" {
  for_each = local.gcp_solo_generated
  length   = 32
  special  = false
}

resource "google_compute_vpn_tunnel" "gcp_solo" {
  for_each = local.gcp_solo_tunnels

  project               = var.project_id
  name                  = each.key
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gateway.id
  peer_gcp_gateway      = each.value.peer_gateway
  vpn_gateway_interface = each.value.gateway_interface
  router                = var.router
  ike_version           = each.value.ike_version
  shared_secret         = each.value.shared_secret.generate ? random_password.gcp_solo_psk[each.key].result : (try(each.value.shared_secret.secret, null) != null ? data.google_secret_manager_secret_version.psk["solo/${each.key}"].secret_data : each.value.shared_secret.value)
}

resource "google_compute_router_interface" "gcp_solo" {
  for_each = local.gcp_solo_sessions

  project    = var.project_id
  region     = var.region
  router     = var.router
  name       = each.value.interface_name
  ip_range   = each.value.local_address_range
  ip_version = each.value.family == "ipv6" ? "IPV6" : null
  vpn_tunnel = google_compute_vpn_tunnel.gcp_solo[each.value.tunnel].name
}

resource "google_compute_router_peer" "gcp_solo" {
  for_each = local.gcp_solo_sessions

  project         = var.project_id
  region          = var.region
  router          = var.router
  name            = each.value.name
  interface       = google_compute_router_interface.gcp_solo[each.key].name
  peer_ip_address = each.value.peer_address
  peer_asn        = each.value.peer_asn
  # v6-interface peers require enable_ipv6 — the API rejects them without it (400, verified live)
  enable_ipv6               = each.value.family == "ipv6"
  enable                    = each.value.enabled
  advertised_route_priority = each.value.advertised_route_priority

  advertise_mode    = try(each.value.advertised, null) != null ? "CUSTOM" : null
  advertised_groups = try(each.value.advertised.groups, null)
  dynamic "advertised_ip_ranges" {
    for_each = try(each.value.advertised.ip_ranges, [])
    content {
      range       = advertised_ip_ranges.value.range
      description = try(advertised_ip_ranges.value.description, null)
    }
  }

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
}
