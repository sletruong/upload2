variable "project_id" {
  description = "Project the subnet is created in — MUST be the network's project (subnets live with their VPC; Shared-VPC service attachment is a consumer-side concern)."
  type        = string
}

variable "name" {
  description = "Subnet name (explicit — the naming layer's contract). Unique per project+region."
  type        = string
}

variable "region" {
  description = "Long-form region."
  type        = string
}

variable "network" {
  description = "Network self link (caller-resolved from the VPC's rendered name — that reference is the ordering)."
  type        = string
}

variable "ipv4_cidr" {
  description = "Primary IPv4 range (provider ip_cidr_range). null ONLY on IPV6_ONLY subnets."
  type        = string
  default     = null

  validation {
    condition     = var.ipv4_cidr == null || can(cidrnetmask(coalesce(var.ipv4_cidr, "0.0.0.0/0")))
    error_message = "ipv4_cidr must be a valid IPv4 CIDR."
  }

  validation {
    condition     = (var.ipv4_cidr == null) == (coalesce(var.stack_type, "IPV4_ONLY") == "IPV6_ONLY")
    error_message = "ipv4_cidr is required — except on IPV6_ONLY subnets, where it must be absent (no IPv4 ranges at all)."
  }
}

variable "description" {
  description = "Subnet description."
  type        = string
  default     = ""
}

variable "secondary_ranges" {
  description = "Alias/secondary IPv4 ranges [{name, ipv4_cidr}] — names are the GKE/alias-IP reference surface and are immutable while consumed. IPv4-only in GCP."
  type = list(object({
    name      = string
    ipv4_cidr = string
  }))
  default  = []
  nullable = false

  validation {
    condition     = length(var.secondary_ranges) == 0 || coalesce(var.stack_type, "IPV4_ONLY") != "IPV6_ONLY"
    error_message = "IPV6_ONLY subnets cannot carry IPv4 secondary ranges."
  }
}

variable "private_ip_google_access" {
  description = "Private Google Access."
  type        = bool
  default     = true

  validation {
    condition     = !var.private_ip_google_access || !contains(["REGIONAL_MANAGED_PROXY", "GLOBAL_MANAGED_PROXY", "PRIVATE_SERVICE_CONNECT", "PRIVATE_NAT"], coalesce(var.purpose, "PRIVATE"))
    error_message = "GCP: proxy-only / PSC / PRIVATE_NAT subnets do not support Private Google Access."
  }
}

variable "flow_logs" {
  description = "VPC Flow Logs; enabled = false omits the log_config block entirely (the API stores none)."
  type = object({
    enabled              = optional(bool, false)
    aggregation_interval = optional(string, "INTERVAL_5_SEC")
    sampling             = optional(number, 0.5)
    metadata             = optional(string, "INCLUDE_ALL_METADATA")
    filter_expr          = optional(string)
    metadata_fields      = optional(list(string))
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.flow_logs.metadata_fields == null || var.flow_logs.metadata == "CUSTOM_METADATA"
    error_message = "metadata_fields requires metadata = CUSTOM_METADATA."
  }

  validation {
    condition     = !var.flow_logs.enabled || !contains(["REGIONAL_MANAGED_PROXY", "GLOBAL_MANAGED_PROXY", "PRIVATE_SERVICE_CONNECT", "PRIVATE_NAT"], coalesce(var.purpose, "PRIVATE"))
    error_message = "GCP: proxy-only / PSC / PRIVATE_NAT subnets do not support VPC Flow Logs."
  }
}

variable "purpose" {
  description = "null = standard PRIVATE subnet. MANAGED_PROXY purposes create proxy-only subnets (stack-derived from the doc's proxy_only block); PSC/NAT/PEER_MIGRATION purposes reserve the range."
  type        = string
  default     = null

  validation {
    condition     = var.purpose == null || contains(["PRIVATE", "REGIONAL_MANAGED_PROXY", "GLOBAL_MANAGED_PROXY", "PRIVATE_SERVICE_CONNECT", "PEER_MIGRATION", "PRIVATE_NAT"], coalesce(var.purpose, "PRIVATE"))
    error_message = "purpose must be PRIVATE, REGIONAL_MANAGED_PROXY, GLOBAL_MANAGED_PROXY, PRIVATE_SERVICE_CONNECT, PEER_MIGRATION, or PRIVATE_NAT."
  }
}

variable "role" {
  description = "MANAGED_PROXY purposes only: ACTIVE | BACKUP. ⚠ NOT OPTIONAL AT THE API — a *_MANAGED_PROXY subnet with no role is REJECTED (\"Subnetwork role must be specified when purpose set to REGIONAL_MANAGED_PROXY\" — verified live; null does NOT fall through to an ACTIVE default). stacks/2-fabric supplies ACTIVE so documents may omit proxy_only.role."
  type        = string
  default     = null

  validation {
    condition     = var.role == null || contains(["REGIONAL_MANAGED_PROXY", "GLOBAL_MANAGED_PROXY"], coalesce(var.purpose, "PRIVATE"))
    error_message = "role is only meaningful on MANAGED_PROXY purposes (the doc's proxy_only block makes role-without-proxy unwritable)."
  }
}

variable "allow_cidr_routes_overlap" {
  description = "HYBRID-subnet enabler (provider allow_subnet_cidr_routes_overlap): BGP-injected more-specific routes may claim destinations INSIDE the subnet ranges — normally such packets drop. Extends the subnet toward on-prem (VM migration)."
  type        = bool
  default     = false

  validation {
    condition     = !var.allow_cidr_routes_overlap || !contains(["REGIONAL_MANAGED_PROXY", "GLOBAL_MANAGED_PROXY", "PRIVATE_SERVICE_CONNECT", "PRIVATE_NAT"], coalesce(var.purpose, "PRIVATE"))
    error_message = "Hybrid overlap only makes sense on standard (PRIVATE) subnets — proxy-only/PSC/NAT subnets cannot extend to on-prem."
  }
}

variable "resolve_subnet_mask" {
  description = "Subnet mask resolution / ARP scope — enable ONLY if the workload VPC needs GCE instances to directly ARP for EACH OTHER (intra-VPC). NOT related to hybrid subnets: hybrid subnets needs proxy-ARP on the ON-PREM side (separate concern), and does NOT require resolve_subnet_mask (verified live with overlapping hybrid subnets and this UNSET — see knowledge-base/decision-guides/migration-ip-preservation.md). Shared 'ARP' term ≠ same thing."
  type        = string
  default     = null

  validation {
    condition     = var.resolve_subnet_mask == null || contains(["ARP_ALL_RANGES", "ARP_PRIMARY_RANGE", "ARP_BROADCAST_PRIMARY_RANGE", "ARP_BROADCAST_PRIMARY_RANGE_WITH_LEARNING"], coalesce(var.resolve_subnet_mask, "x"))
    error_message = "resolve_subnet_mask must be ARP_ALL_RANGES, ARP_PRIMARY_RANGE, ARP_BROADCAST_PRIMARY_RANGE, or ARP_BROADCAST_PRIMARY_RANGE_WITH_LEARNING."
  }
}

variable "stack_type" {
  description = "null = IPV4_ONLY. IPV4_IPV6 = dual stack; IPV6_ONLY = v6-only (both need ipv6_access_type)."
  type        = string
  default     = null

  validation {
    condition     = var.stack_type == null || contains(["IPV4_ONLY", "IPV4_IPV6", "IPV6_ONLY"], coalesce(var.stack_type, "x"))
    error_message = "stack_type must be IPV4_ONLY, IPV4_IPV6, or IPV6_ONLY."
  }

  validation {
    condition     = contains(["IPV4_IPV6", "IPV6_ONLY"], coalesce(var.stack_type, "IPV4_ONLY")) == (var.ipv6_access_type != null)
    error_message = "ipv6_access_type must be set exactly when the stack carries IPv6 (IPV4_IPV6 / IPV6_ONLY) — it is immutable once dual-stack, so the framework demands it up front."
  }
}

variable "ipv6_access_type" {
  description = "INTERNAL (ULA from the VPC's range — VPC must enable it) or EXTERNAL (auto-allocated global; no direct path). IMMUTABLE once the subnet is IPv6-bearing."
  type        = string
  default     = null

  validation {
    condition     = var.ipv6_access_type == null || contains(["INTERNAL", "EXTERNAL"], coalesce(var.ipv6_access_type, "x"))
    error_message = "ipv6_access_type must be INTERNAL or EXTERNAL."
  }
}

variable "private_ipv6_google_access" {
  description = "IPv6 counterpart of Private Google Access; only meaningful on IPv6-bearing subnets."
  type        = string
  default     = null

  validation {
    condition     = var.private_ipv6_google_access == null || contains(["DISABLE_GOOGLE_ACCESS", "ENABLE_BIDIRECTIONAL_ACCESS_TO_GOOGLE", "ENABLE_OUTBOUND_VM_ACCESS_TO_GOOGLE"], coalesce(var.private_ipv6_google_access, "x"))
    error_message = "private_ipv6_google_access must be DISABLE_GOOGLE_ACCESS, ENABLE_BIDIRECTIONAL_ACCESS_TO_GOOGLE, or ENABLE_OUTBOUND_VM_ACCESS_TO_GOOGLE."
  }

  validation {
    condition     = var.private_ipv6_google_access == null || coalesce(var.stack_type, "IPV4_ONLY") == "IPV4_IPV6"
    error_message = "private_ipv6_google_access is DUAL-STACK (IPV4_IPV6) only — the API rejects it on IPV6_ONLY subnets (live-verified) and it is meaningless on IPV4_ONLY."
  }
}

variable "ipv6_cidr" {
  description = "OPTIONAL explicit IPv6 range (lexicon pair of ipv4_cidr; omit for auto-assign — the normal case). Routed by ipv6_access_type: EXTERNAL -> external_ipv6_prefix, INTERNAL -> internal_ipv6_prefix."
  type        = string
  default     = null

  validation {
    condition     = var.ipv6_cidr == null || contains(["IPV4_IPV6", "IPV6_ONLY"], coalesce(var.stack_type, "IPV4_ONLY"))
    error_message = "ipv6_cidr requires an IPv6-bearing stack_type."
  }
}

variable "iam" {
  description = "Subnet IAM keyed by ROLE -> AUTHORITATIVE member list (google_compute_subnetwork_iam_binding — the document is truth per role). roles/compute.networkUser is the Shared-VPC service-project grant; host enablement lives in the project factory, not this repo."
  type        = map(list(string))
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for r, m in var.iam : can(regex("^roles/", r)) && length(m) > 0])
    error_message = "iam keys must be full role names (roles/...) with at least one member each."
  }
}
