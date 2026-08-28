variable "project_id" {
  description = "Project (the router's)."
  type        = string
}

variable "name" {
  description = "Private NAT name (explicit)."
  type        = string
}

variable "region" {
  description = "Long-form region (the router's)."
  type        = string
}

variable "router" {
  description = "Router NAME this NAT is configured on."
  type        = string
}

variable "subnetworks" {
  description = "Source subnets (self links, caller-resolved). Private NAT has no ALL_SUBNETWORKS mode — the list IS the scope."
  type = list(object({
    self_link = string
    ranges = optional(object({
      all         = optional(bool)
      primary     = optional(bool)
      secondaries = optional(list(string), [])
    }))
  }))

  validation {
    # second gate for the schema's XOR: contradictions are rejected here too,
    # never silently resolved by translation precedence
    # typed optionals surface as NULL attributes — try() only catches errors,
    # so the checks compare against null/true directly
    condition = alltrue([
      for s in var.subnetworks : s.ranges == null ? true : (
        s.ranges.all == true
        ? s.ranges.primary == null && length(s.ranges.secondaries) == 0
        : s.ranges.primary == true || length(s.ranges.secondaries) > 0
      )
    ])
    error_message = "ranges is a COMPLETE selection statement: {all: true} XOR ({primary: true} and/or {secondaries: [...]}) — an object selecting nothing, or contradicting all:, is invalid."
  }

  validation {
    condition     = length(var.subnetworks) > 0
    error_message = "Private NAT requires at least one source subnet."
  }
}

variable "nat64_subnetworks" {
  description = "BETA (GCP Preview): subnet self links whose IPv6 traffic gets private NAT64 (allocation stays the v4 PRIVATE_NAT ranges in rules). Presence derives the wire mode."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "rules" {
  description = "Rules keyed by RULE NUMBER: CEL match (NCC form: nexthop.hub == \"//networkconnectivity...\") -> allocation from PRIVATE_NAT-purpose subnet ranges (self links, caller-resolved)."
  type = map(object({
    match         = string
    active_ranges = list(string)
    drain_ranges  = optional(list(string), [])
    description   = optional(string)
  }))
  nullable = false

  validation {
    condition     = length(var.rules) > 0 && alltrue([for n, r in var.rules : length(r.active_ranges) > 0])
    error_message = "Private NAT translates ONLY what rules match — at least one rule with at least one active range."
  }
}

variable "min_ports_per_vm" {
  description = "Minimum ports per VM (dynamic allocation raises from here)."
  type        = number
  default     = null

  validation {
    # ternary = the lazy form (|| evaluates both sides; contains(null) explodes)
    condition     = var.min_ports_per_vm == null ? true : (!var.enable_dynamic_port_allocation ? true : contains([32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536], var.min_ports_per_vm))
    error_message = "min_ports_per_vm under dynamic allocation must be a power of two >= 32 (API; static allocation input is unrestricted)."
  }
}

variable "max_ports_per_vm" {
  description = "Maximum ports per VM (dynamic port allocation only)."
  type        = number
  default     = null

  validation {
    # the port-family checks all live HERE (edges max->{dynamic,min} only;
    # a validation on dynamic referencing max creates a var-validation CYCLE)
    condition = var.max_ports_per_vm == null ? true : (
      var.enable_dynamic_port_allocation &&
      contains([64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536], var.max_ports_per_vm) &&
      (var.min_ports_per_vm == null || var.max_ports_per_vm > var.min_ports_per_vm)
    )
    error_message = "max_ports_per_vm: requires dynamic allocation; must be a power of two (64-65536) STRICTLY greater than min_ports_per_vm (API)."
  }
}

variable "enable_dynamic_port_allocation" {
  description = "Dynamic port allocation."
  type        = bool
  default     = false

}

variable "timeouts" {
  description = "Idle timeouts (seconds); nulls = provider defaults."
  type = object({
    icmp            = optional(number)
    tcp_established = optional(number)
    tcp_transitory  = optional(number)
    tcp_time_wait   = optional(number)
    udp             = optional(number)
  })
  default  = {}
  nullable = false
}

variable "logging" {
  description = "NAT logging; enabled=false omits the block."
  type = object({
    enabled = optional(bool, false)
    filter  = optional(string, "ERRORS_ONLY")
  })
  default  = {}
  nullable = false
}
