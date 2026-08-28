variable "project_id" {
  description = "The VPC's project."
  type        = string
}

variable "network" {
  description = "Network self link (caller-resolved from the enclosing VPC — the ordering edge)."
  type        = string
}

variable "ranges" {
  description = "Reserved PSA ranges: explicit names + Manual (ipv4_cidr) XOR Automatic (ipv4_prefix_length - GCP picks a free block). All feed ONE servicenetworking connection (GCP: one per network+service); the connection references ranges BY NAME."
  type = list(object({
    name               = string
    ipv4_cidr          = optional(string)
    ipv4_prefix_length = optional(number)
  }))

  validation {
    condition     = length(var.ranges) > 0
    error_message = "PSA needs at least one reserved range."
  }

  validation {
    condition     = alltrue([for r in var.ranges : (r.ipv4_cidr != null) != (r.ipv4_prefix_length != null)])
    error_message = "Each range is Manual (ipv4_cidr) XOR Automatic (ipv4_prefix_length) - exactly one."
  }

  validation {
    condition     = alltrue([for r in var.ranges : r.ipv4_cidr == null || can(cidrnetmask(r.ipv4_cidr))])
    error_message = "ipv4_cidr entries must be valid IPv4 CIDRs."
  }
}

variable "export_custom_routes" {
  description = "Export custom routes to the service producer over the PSA peering."
  type        = bool
  default     = false
}

variable "import_custom_routes" {
  description = "Import the producer's custom routes."
  type        = bool
  default     = false
}

variable "deletion_policy" {
  description = "delete (THE DESIGN, ruled 2026-08-15 — teardown must tear down; intermittent producer-GC wedge is a GCP defect to wait out/triage, never a reason to abandon) | abandon (legacy/discouraged: leaves an unmanaged connection)."
  type        = string
  default     = "delete"
}
