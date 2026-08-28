variable "name" {
  description = "Association name — plumbing (caller derives from the network; unique per endpoint since an endpoint associates with a network at most once)."
  type        = string
}

variable "project_id" {
  description = "The VPC's project (associations are project resources, regardless of the endpoint's parent)."
  type        = string
}

variable "zone" {
  description = "The endpoint's zone (associations are zonal, colocated with their endpoint)."
  type        = string
}

variable "endpoint" {
  description = "FULL endpoint id (caller-constructed from target + zone + rendered name: <org|project>/locations/<zone>/firewallEndpoints/<name>) — names-as-contract across the stage boundary; the endpoint exists by stage order."
  type        = string

  validation {
    condition     = can(regex("^(organizations|projects)/[^/]+/locations/[^/]+/firewallEndpoints/[a-z]([a-z0-9-]*[a-z0-9])?$", var.endpoint))
    error_message = "endpoint must be the full id: organizations|projects/<parent>/locations/<zone>/firewallEndpoints/<name>."
  }
}

variable "network" {
  description = "Network self link (caller-resolved from the enclosing VPC — the ordering edge)."
  type        = string
}

variable "tls_inspection_policy" {
  description = "Optional TLS inspection policy id to decrypt with (a future family; full path passthrough today)."
  type        = string
  default     = null
}

variable "enabled" {
  description = "false = association present but inspection OFF (traffic flows uninspected — the safe-rollback lever; wire: disabled=true)."
  type        = bool
  default     = true
}
