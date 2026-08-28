variable "project_id" {
  description = "Project the router is created in (the VPC's project — routers nest under their VPC)."
  type        = string
}

variable "name" {
  description = "Router name (explicit — the naming layer's contract)."
  type        = string
}

variable "region" {
  description = "Long-form region."
  type        = string
}

variable "network" {
  description = "Network self link (caller-resolved from the enclosing VPC — the ordering edge)."
  type        = string
}

variable "description" {
  description = "Router description."
  type        = string
  default     = ""
}

variable "bgp" {
  description = "BGP block; null = NAT-only router (no BGP). advertise_mode CUSTOM requires groups and/or ip_ranges; DEFAULT forbids them (provider/API constraint)."
  type = object({
    asn               = number
    advertise_mode    = optional(string, "DEFAULT")
    advertised_groups = optional(list(string), [])
    advertised_ip_ranges = optional(list(object({
      range       = string
      description = optional(string)
    })), [])
    keepalive_interval = optional(number)
  })
  default = null

  validation {
    condition     = var.bgp == null || contains(["DEFAULT", "CUSTOM"], try(var.bgp.advertise_mode, "DEFAULT"))
    error_message = "bgp.advertise_mode must be DEFAULT or CUSTOM."
  }

  validation {
    condition = var.bgp == null ? true : (
      var.bgp.advertise_mode == "CUSTOM"
      ? length(var.bgp.advertised_groups) + length(var.bgp.advertised_ip_ranges) > 0
      : length(var.bgp.advertised_groups) + length(var.bgp.advertised_ip_ranges) == 0
    )
    error_message = "advertise_mode CUSTOM requires advertised_groups and/or advertised_ip_ranges; DEFAULT forbids them."
  }

  validation {
    condition     = var.bgp == null || try(var.bgp.asn >= 64512 && var.bgp.asn <= 65534 || var.bgp.asn >= 4200000000 && var.bgp.asn <= 4294967294, false)
    error_message = "bgp.asn must be a private ASN (64512-65534 or 4200000000-4294967294)."
  }
}

variable "interfaces" {
  description = "NCC/appliance router interfaces keyed by name: a REUSABLE BGP peering surface (subnet + private_address, optional redundant a/b pair) serving many sessions — fabric library. Tunnel/attachment-bound interfaces are 1:1 plumbing owned by their 4-hybrid connection."
  type = map(object({
    subnetwork          = string
    private_address     = string
    redundant_interface = optional(string)
  }))
  default  = {}
  nullable = false


  validation {
    condition = alltrue([
      for k, i in var.interfaces : i.redundant_interface == null || (
        contains(keys(var.interfaces), coalesce(i.redundant_interface, "__none__")) &&
        try(var.interfaces[coalesce(i.redundant_interface, "__none__")].redundant_interface, "x") == null
      )
    ])
    error_message = "redundant_interface must name a SIBLING interface on this router, and that sibling must be a primary (no redundant chains)."
  }
}

variable "route_policies" {
  description = "Router-scoped BGP route policies keyed by name — the policy LIBRARY. Inert until a peer subscribes (import/export_policies on the session, hybrid/appliance stages, by name). terms = priority-ordered CEL match -> CEL actions (opaque strings to the framework; the API validates CEL)."
  type = map(object({
    type = string
    terms = list(object({
      priority = number
      match    = string
      actions  = optional(list(string), [])
    }))
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k, p in var.route_policies : contains(["IMPORT", "EXPORT"], p.type)])
    error_message = "route policy type must be IMPORT or EXPORT."
  }

  validation {
    condition     = alltrue([for k, p in var.route_policies : length(p.terms) == length(distinct([for t in p.terms : t.priority]))])
    error_message = "term priorities must be unique within a policy (they are the evaluation order)."
  }
}

variable "pre_existing" {
  description = "true = router exists and is NOT managed here; nothing is read from it (children attach by name/path — no data source: data references only when deployment needs an element). bgp/description rejected upstream — children yes, attributes never."
  type        = bool
  default     = false
}
