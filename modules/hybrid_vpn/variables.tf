variable "project_id" {
  description = "The fabric VPC's project (gateway, tunnels, and sessions live with the network)."
  type        = string
}

variable "name" {
  description = "HA VPN gateway name (explicit — the connection's anchor)."
  type        = string
}

variable "region" {
  description = "Long-form region (gateway, router, tunnels all colocate)."
  type        = string
}

variable "network" {
  description = "Fabric VPC self link (caller-constructed from the rendered name)."
  type        = string
}

variable "router" {
  description = "Fabric Cloud Router NAME (rendered — sessions and tunnel interfaces attach to it)."
  type        = string
}

variable "external_peers" {
  description = "External peers: each an external_vpn_gateway + tunnels. Every tunnel carries BGP SESSIONS TYPED BY FAMILY (ipv4/ipv6/both — console permutations), each session owning its 1:1 router interface. Addressing per session: local_address_range + peer_address together (Manual) or neither (Automatic — GCP allocates). shared_secret: value XOR generate."
  type = list(object({
    name            = string
    description     = optional(string, "")
    redundancy_type = optional(string, "TWO_IPS_REDUNDANCY")
    interfaces = list(object({
      ipv4_address = optional(string)
      ipv6_address = optional(string)
    }))
    tunnels = list(object({
      name              = string
      gateway_interface = number
      peer_interface    = optional(number, 0)
      ike_version       = optional(number, 2)
      shared_secret = object({
        value    = optional(string)
        generate = optional(bool, false)
        secret   = optional(string)
      })
      bgp_sessions = map(object({
        name                      = string
        enabled                   = optional(bool, true)
        exchange_ipv6             = optional(bool, false)
        exchange_ipv4             = optional(bool, false)
        peer_asn                  = number
        advertised_route_priority = optional(number)
        advertised = optional(object({
          groups    = optional(list(string))
          ip_ranges = optional(list(object({ range = string, description = optional(string) })))
        }))
        custom_learned_routes = optional(object({
          ranges   = list(string)
          priority = optional(number)
        }))
        interface_name      = string
        local_address_range = optional(string)
        peer_address        = optional(string)
        import_policies     = optional(list(string), [])
        export_policies     = optional(list(string), [])
      }))
    }))
  }))
  default  = []
  nullable = false

  validation {
    condition = alltrue(flatten([
      for p in var.external_peers : [
        for t in p.tunnels : length([for x in [t.shared_secret.value != null, t.shared_secret.generate, try(t.shared_secret.secret, null) != null] : x if x]) == 1
      ]
    ]))
    error_message = "Each tunnel's shared_secret is exactly ONE of: value (inline) XOR generate: true XOR secret (Secret Manager ref)."
  }

  validation {
    condition = alltrue(flatten([
      for p in var.external_peers : [for t in p.tunnels : contains([0, 1], t.gateway_interface)]
    ]))
    error_message = "gateway_interface must be 0 or 1 (HA VPN gateways have exactly two)."
  }

  validation {
    condition = alltrue(flatten([
      for p in var.external_peers : [
        for t in p.tunnels : alltrue([for fam, ss in t.bgp_sessions : contains(["ipv4", "ipv6"], fam)])
      ]
    ]))
    error_message = "bgp_sessions keys must be ipv4 and/or ipv6 (family-typed)."
  }

  validation {
    condition = alltrue(flatten([
      for p in var.external_peers : [
        for t in p.tunnels : alltrue([
          for fam, ss in t.bgp_sessions : (ss.local_address_range != null) == (ss.peer_address != null)
        ])
      ]
    ]))
    error_message = "Session addressing is Manual (local_address_range AND peer_address) or Automatic (NEITHER) — never one-sided."
  }

  validation {
    condition = alltrue(flatten([
      for p in var.external_peers : [
        for t in p.tunnels : (
          try(t.bgp_sessions["ipv4"].local_address_range, null) == null ||
          can(regex("^169\\.254\\.", t.bgp_sessions["ipv4"].local_address_range))
        )
      ]
    ]))
    error_message = "IPv4 session addressing must be link-local (169.254.0.0/16)."
  }

  validation {
    # Per tunnel, a family is learned once (native XOR opposite exchange)
    condition = alltrue(flatten([
      for p in var.external_peers : [
        for t in p.tunnels : !(
          (contains(keys(t.bgp_sessions), "ipv6") && try(t.bgp_sessions["ipv4"].exchange_ipv6, false)) ||
          (contains(keys(t.bgp_sessions), "ipv4") && try(t.bgp_sessions["ipv6"].exchange_ipv4, false))
        )
      ]
    ]))
    error_message = "A route family is learned once per tunnel - a native session and the opposite session's exchange_* flag for the same family are mutually exclusive."
  }
}

variable "ncc_spoke" {
  description = "Optional NCC hybrid spoke over ALL tunnels (external + gcp). site_to_site_data_transfer stays false cross-VPC — the API restricts it to single-VPC shapes (verified live). include_import_ranges ALL_IPV4_RANGES imports the hub table (incl. producer-spoke ranges — verified on a live apply) for announcement to the far side. group: star hubs place hybrid spokes center|edge."
  type = object({
    name                       = string
    hub                        = string
    site_to_site_data_transfer = optional(bool, false)
    include_import_ranges      = optional(list(string))
    group                      = optional(string)
  })
  default = null
}

variable "stack_type" {
  description = "Underlay stack: IPV4_ONLY (default) | IPV4_IPV6 - required beneath native ipv6 bgp_sessions."
  type        = string
  default     = null

  validation {
    condition     = var.stack_type == null || contains(["IPV4_ONLY", "IPV4_IPV6"], coalesce(var.stack_type, "x"))
    error_message = "stack_type must be IPV4_ONLY or IPV4_IPV6."
  }
}

variable "gcp_peer_pairs" {
  description = "GCP<->GCP BOTH-SIDES pairs (the peering_pairs analog: one declaration, two sides — the API rejects external-gateway modeling of GCP HA gateway IPs (verified live), so peer_gcp_gateway is the ONLY path). ONE entry creates BOTH sides: near tunnels/sessions on this doc's gateway+router, far tunnels/sessions on the named peer gateway+router — one PSK, no two-phase bootstrap. Manual addressing REQUIRED (verified live: Automatic GCP<->GCP never converges). Interface pairing is i<->i; one tunnel per (interface, peer gateway)."
  type = list(object({
    name            = string
    peer_gateway    = string # far HA VPN gateway ID (caller-constructed path)
    peer_router     = string # far Cloud Router NAME
    peer_project_id = optional(string)
    local_asn       = number # this side's CR ASN (far sessions peer at it)
    peer_asn        = number # far CR ASN (near sessions peer at it)
    tunnels = list(object({
      name              = string
      peer_tunnel_name  = string
      gateway_interface = number
      ike_version       = optional(number, 2)
      shared_secret = object({
        value    = optional(string)
        generate = optional(bool, false)
        secret   = optional(string)
      })
      bgp_sessions = map(object({
        name                      = string
        peer_session_name         = string
        interface_name            = string
        peer_interface_name       = string
        enabled                   = optional(bool, true)
        advertised_route_priority = optional(number)
        advertised = optional(object({
          groups    = optional(list(string))
          ip_ranges = optional(list(object({ range = string, description = optional(string) })))
        }))
        custom_learned_routes = optional(object({
          ranges   = list(string)
          priority = optional(number)
        }))
        local_address_range = string # Manual REQUIRED (GCP<->GCP law)
        peer_address        = string
        import_policies     = optional(list(string), [])
        export_policies     = optional(list(string), [])
      }))
    }))
  }))
  default  = []
  nullable = false

  validation {
    condition = alltrue([
      for p in var.gcp_peer_pairs :
      length(p.tunnels) == length(distinct([for t in p.tunnels : t.gateway_interface]))
    ])
    error_message = "One tunnel per (gateway interface, peer gateway) — duplicate gateway_interface within a gcp_peer entry."
  }

  validation {
    condition = alltrue(flatten([
      for p in var.gcp_peer_pairs : [
        for t in p.tunnels : length([for x in [t.shared_secret.value != null, t.shared_secret.generate, try(t.shared_secret.secret, null) != null] : x if x]) == 1
      ]
    ]))
    error_message = "Each tunnel's shared_secret is exactly ONE of: value (inline) XOR generate: true XOR secret (Secret Manager ref)."
  }
}

variable "gcp_peers" {
  description = "GCP<->GCP ONE-SIDE peers (the peering analog: this side only — the far side is someone else's document/apply or pre-existing). Tunnels target an EXISTING peer gateway; GATEWAY-BEFORE-TUNNEL race is the caller's contract (apply gateways first, or use gcp_peer_pairs). PSK: value (agreed out-of-band) or generate (hand the output to the far side)."
  type = list(object({
    name         = string
    peer_gateway = string
    tunnels = list(object({
      name              = string
      gateway_interface = number
      ike_version       = optional(number, 2)
      shared_secret = object({
        value    = optional(string)
        generate = optional(bool, false)
        secret   = optional(string)
      })
      bgp_sessions = map(object({
        name                      = string
        interface_name            = string
        enabled                   = optional(bool, true)
        peer_asn                  = number
        advertised_route_priority = optional(number)
        advertised = optional(object({
          groups    = optional(list(string))
          ip_ranges = optional(list(object({ range = string, description = optional(string) })))
        }))
        custom_learned_routes = optional(object({
          ranges   = list(string)
          priority = optional(number)
        }))
        local_address_range = string
        peer_address        = string
        import_policies     = optional(list(string), [])
        export_policies     = optional(list(string), [])
      }))
    }))
  }))
  default  = []
  nullable = false

  validation {
    condition = alltrue([
      for p in var.gcp_peers :
      length(p.tunnels) == length(distinct([for t in p.tunnels : t.gateway_interface]))
    ])
    error_message = "One tunnel per (gateway interface, peer gateway)."
  }

  # Same PSK contract as external_peers/gcp_peer_pairs. Without this guard
  # an all-null shared_secret passes plan and fails at APPLY.
  validation {
    condition = alltrue(flatten([
      for p in var.gcp_peers : [
        for t in p.tunnels : length([for x in [t.shared_secret.value != null, t.shared_secret.generate, try(t.shared_secret.secret, null) != null] : x if x]) == 1
      ]
    ]))
    error_message = "Each tunnel's shared_secret is exactly ONE of: value (inline) XOR generate: true XOR secret (Secret Manager ref)."
  }
}
