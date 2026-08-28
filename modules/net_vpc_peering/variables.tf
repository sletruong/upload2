variable "name" {
  description = "Peering name (explicit — the naming layer's contract). Unique per network."
  type        = string
}

variable "network" {
  description = "This side's network (self link — caller-resolved from the enclosing VPC; the ordering edge)."
  type        = string
}

variable "peer_network" {
  description = "The other side's network: caller-resolved self link (in-stage peer by rendered name) or full projects/<p>/global/networks/<n> path (external). NOTE: a peering is ACTIVE only when BOTH sides declare it — each VPC document owns its own side."
  type        = string
}

variable "export_custom_routes" {
  description = "Export custom (static/dynamic) routes to the peer."
  type        = bool
  default     = false
}

variable "import_custom_routes" {
  description = "Import the peer's custom routes."
  type        = bool
  default     = false
}

variable "export_subnet_routes_with_public_ip" {
  description = "Export subnet routes whose ranges are public IPs."
  type        = bool
  default     = false
}

variable "import_subnet_routes_with_public_ip" {
  description = "Import peer subnet routes with public-IP ranges."
  type        = bool
  default     = false
}

variable "stack_type" {
  description = "IPV4_ONLY | IPV4_IPV6 (null = provider default)."
  type        = string
  default     = null

  validation {
    condition     = var.stack_type == null || contains(["IPV4_ONLY", "IPV4_IPV6"], coalesce(var.stack_type, "x"))
    error_message = "stack_type must be IPV4_ONLY or IPV4_IPV6."
  }
}
