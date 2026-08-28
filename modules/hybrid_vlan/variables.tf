variable "project_id" {
  description = "The fabric VPC's project."
  type        = string
}

variable "name" {
  description = "VLAN attachment name (explicit)."
  type        = string
}

variable "region" {
  description = "Long-form region."
  type        = string
}

variable "router" {
  description = "Fabric Cloud Router NAME (rendered)."
  type        = string
}

variable "type" {
  description = "DEDICATED | PARTNER."
  type        = string

  validation {
    condition     = contains(["DEDICATED", "PARTNER"], var.type)
    error_message = "type must be DEDICATED or PARTNER."
  }

  validation {
    condition     = (var.type == "DEDICATED") == (var.interconnect != null)
    error_message = "interconnect must be set exactly when type = DEDICATED."
  }

  validation {
    condition     = (var.type == "PARTNER") == (var.edge_availability_domain != null)
    error_message = "edge_availability_domain must be set exactly when type = PARTNER."
  }
}

variable "interconnect" {
  description = "DEDICATED only: the physical interconnect."
  type        = string
  default     = null
}

variable "edge_availability_domain" {
  description = "PARTNER only: AVAILABILITY_DOMAIN_1|2|ANY."
  type        = string
  default     = null

  validation {
    condition     = var.edge_availability_domain == null || contains(["AVAILABILITY_DOMAIN_1", "AVAILABILITY_DOMAIN_2", "AVAILABILITY_DOMAIN_ANY"], coalesce(var.edge_availability_domain, "x"))
    error_message = "edge_availability_domain must be AVAILABILITY_DOMAIN_1, AVAILABILITY_DOMAIN_2, or AVAILABILITY_DOMAIN_ANY."
  }
}

variable "bandwidth" {
  description = "Attachment bandwidth (null = provider default / partner-set)."
  type        = string
  default     = null
}

variable "vlan_tag" {
  description = "DEDICATED only: 802.1q tag."
  type        = number
  default     = null

  validation {
    condition     = var.vlan_tag == null || var.type == "DEDICATED"
    error_message = "vlan_tag is DEDICATED-only."
  }
}

variable "admin_enabled" {
  description = "Attachment admin state."
  type        = bool
  default     = true
}

variable "bgp_sessions" {
  # (the once-per-family gate lives in the validation below)
  description = "FAMILY-TYPED BGP sessions (ipv4/ipv6/both), each owning its 1:1 router interface. DEDICATED: Manual addressing (local_address_range + peer_address) or Automatic (neither). PARTNER: addressing always derives from pairing (v4) / allocation (v6) — the stack forbids explicit values."
  type = map(object({
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
  nullable = false

  validation {
    condition     = length(var.bgp_sessions) > 0 && alltrue([for fam, s in var.bgp_sessions : contains(["ipv4", "ipv6"], fam)])
    error_message = "bgp_sessions needs at least one family key (ipv4 and/or ipv6)."
  }

  validation {
    condition     = alltrue([for fam, s in var.bgp_sessions : (s.local_address_range != null) == (s.peer_address != null)])
    error_message = "Session addressing is Manual (both) or Automatic (neither) — never one-sided."
  }

  validation {
    # A route family is learned ONCE per attachment — native session XOR
    # the opposite session's exchange flag (verified live)
    condition = !(
      (contains(keys(var.bgp_sessions), "ipv6") && try(var.bgp_sessions["ipv4"].exchange_ipv6, false)) ||
      (contains(keys(var.bgp_sessions), "ipv4") && try(var.bgp_sessions["ipv6"].exchange_ipv4, false))
    )
    error_message = "A route family is learned once per attachment - a native session and the opposite session's exchange_* flag for the same family are mutually exclusive."
  }
}

variable "ncc_spoke" {
  description = "Optional NCC hybrid spoke over this attachment. site_to_site_data_transfer stays false cross-VPC — the API rejects it for cross-VPC hybrid spokes (verified live). include_import_ranges = hub-table import filter (parity with the vpn spoke). group: hub group URL (caller-constructed, REAL group names)."
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
