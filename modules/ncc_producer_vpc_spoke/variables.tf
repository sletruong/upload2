variable "project_id" {
  description = "Project the spoke is created in (the VPC's project)."
  type        = string
}

variable "name" {
  description = "Spoke name (explicit — the naming layer's contract)."
  type        = string
}

variable "hub" {
  description = "Full hub URI (projects/<hub-project>/locations/global/hubs/<name>) — caller-constructed from the hub's RENDERED name (names-as-contract; the hub is tier-0 content in another state)."
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/locations/global/hubs/[a-z]([a-z0-9-]*[a-z0-9])?$", var.hub))
    error_message = "hub must be a full URI: projects/<project>/locations/global/hubs/<name>."
  }
}

variable "group" {
  description = "Full group URI (<hub>/groups/<token>). mesh hubs use default; star hubs center|edge."
  type        = string
}

variable "network" {
  description = "VPC self link (caller-resolved — the ordering edge to this stage's VPC)."
  type        = string
}

variable "description" {
  description = "Spoke description."
  type        = string
  default     = ""
}

variable "include_export_ranges" {
  description = "CIDRs this spoke EXPORTS to the hub (empty = all). Named for what it does: an EXPORT filter — not to be confused with the hybrid spokes' include_import_ranges, which filters hub-table imports. Composes with exclude_export_ranges (excludes = subsets of this set)."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    # include+exclude COMPOSE (excludes must be subsets of the include
    # set) — they are NOT mutually exclusive; verified on a live apply. A v6
    # exclude REQUIRES an include covering v6 (default include set is v4-only).
    condition     = !anytrue([for r in var.exclude_export_ranges : can(regex(":", r))]) || anytrue([for r in var.include_export_ranges : can(regex(":", r)) || r == "ALL_IPV6_RANGES"])
    error_message = "A v6 exclude_export_range requires include_export_ranges to cover v6 (ALL_IPV6_RANGES or explicit v6 CIDRs) - the default include set is v4-only."
  }
}

variable "exclude_export_ranges" {
  description = "CIDRs this spoke WITHHOLDS from the hub."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "labels" {
  description = "GCP labels."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "peering" {
  description = "Name of the PSA peering the producer network hangs off (the servicenetworking connection on the linked VPC — which must exist: PSA is its own fabric item)."
  type        = string
  default     = "servicenetworking-googleapis-com"
}
