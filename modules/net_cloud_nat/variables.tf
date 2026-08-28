variable "project_id" {
  description = "Project (the router's — NATs nest under their router)."
  type        = string
}

variable "name" {
  description = "NAT name (explicit — the naming layer's contract)."
  type        = string
}

variable "region" {
  description = "Long-form region (the router's)."
  type        = string
}

variable "router" {
  description = "Router NAME this NAT is configured on (caller passes the enclosing router's resolved name — the ordering edge)."
  type        = string
}

variable "nat_addresses" {
  description = "BROUGHT address self links (caller-resolved: external family refs or raw paths). Concatenated with static_addresses — per-entry lifecycle upstream. Both empty = AUTO_ONLY."
  type        = list(string)
  default     = []
  nullable    = false

}

variable "static_addresses" {
  description = "External addresses CREATED for this NAT — every address is EXPLICITLY named (the naming contract forbids generated suffixes). Count = list length."
  type = list(object({
    name = string
  }))
  default  = []
  nullable = false
}

variable "source_subnetwork_ip_ranges_to_nat" {
  description = "Which subnets NAT: ALL_SUBNETWORKS_ALL_IP_RANGES | ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES | LIST_OF_SUBNETWORKS (then pass subnetworks)."
  type        = string
  default     = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  validation {
    condition     = contains(["ALL_SUBNETWORKS_ALL_IP_RANGES", "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES", "LIST_OF_SUBNETWORKS"], var.source_subnetwork_ip_ranges_to_nat)
    error_message = "source_subnetwork_ip_ranges_to_nat must be ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, or LIST_OF_SUBNETWORKS."
  }

  validation {
    condition     = (var.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS") == (length(var.subnetworks) > 0)
    error_message = "subnetworks must be set exactly when source mode is LIST_OF_SUBNETWORKS."
  }
}

variable "subnetworks" {
  description = "LIST_OF_SUBNETWORKS mode: caller-resolved subnet self links + which of their ranges to NAT."
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
  default  = []
  nullable = false
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
  description = "Dynamic port allocation (requires endpoint-independent mapping DISABLED — provider/API constraint)."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_dynamic_port_allocation || !var.enable_endpoint_independent_mapping
    error_message = "Dynamic port allocation requires enable_endpoint_independent_mapping = false (API constraint)."
  }

}

variable "enable_endpoint_independent_mapping" {
  description = "Endpoint-independent mapping."
  type        = bool
  default     = false
}

variable "endpoint_types" {
  description = <<-EOT
    Which endpoint kinds this gateway serves. Omit = provider default
    (ENDPOINT_TYPE_VM), which is what every NAT in the estate wants today.

    ⚠ IMMUTABLE IN PRACTICE: changing endpoint_types forces REPLACEMENT of
    the gateway, and replacement means egress stops for every instance
    behind it. Decide at create time.

    ⚠ SWG and MANAGED_PROXY_LB gateways serve Secure Web Proxy and
    proxy-only subnets — NOT VMs. A gateway is one kind; it does not
    multiplex, so a VM-serving NAT and an SWG NAT are two gateways.
  EOT
  type        = list(string)
  default     = null

  validation {
    # ⚠ TERNARY, NOT `||` — HCL does NOT short-circuit, so the `x == null ||`
    # form still EVALUATES the right-hand side and throws "Iteration over
    # null value" (design_and_backlog/DESIGN-DOCTRINE.md §7).
    condition = var.endpoint_types == null ? true : alltrue([
      for e in var.endpoint_types : contains(
        ["ENDPOINT_TYPE_VM", "ENDPOINT_TYPE_SWG", "ENDPOINT_TYPE_MANAGED_PROXY_LB"], e
      )
    ])
    error_message = "endpoint_types entries must be ENDPOINT_TYPE_VM, ENDPOINT_TYPE_SWG or ENDPOINT_TYPE_MANAGED_PROXY_LB."
  }
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

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.logging.filter)
    error_message = "logging.filter must be ERRORS_ONLY, TRANSLATIONS_ONLY, or ALL."
  }
}

variable "nat64_subnetworks" {
  description = "Subnet self links (caller-resolved) whose IPv6 traffic gets NAT64 to this NAT's v4 pool. Presence derives wire mode LIST_OF_IPV6_SUBNETWORKS; empty = no NAT64. ALL_IPV6_SUBNETWORKS deliberately unexposed (exclusive singleton)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "rules" {
  description = "NAT rules keyed by RULE NUMBER (the identity — policy-priority grammar). match = CEL (opaque; API validates). active/drain IPs: this NAT's static_addresses by NAME (resolved here) or full address self links. Requires MANUAL allocation."
  type = map(object({
    match            = string
    active_addresses = list(string)
    drain_addresses  = optional(list(string), [])
    description      = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = length(var.rules) == 0 || length(var.nat_addresses) + length(var.static_addresses) > 0
    error_message = "NAT rules require MANUAL IP allocation (static_addresses or nat_addresses) — their action IPs must come from the NAT's own set."
  }

  validation {
    condition     = alltrue([for n, r in var.rules : length(r.active_addresses) > 0])
    error_message = "Every NAT rule needs at least one active IP."
  }
}
