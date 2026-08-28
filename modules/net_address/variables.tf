variable "project_id" {
  description = "Project the address lives in."
  type        = string
}

variable "name" {
  description = "Address resource name (explicit — the family reference surface)."
  type        = string
}

variable "scope" {
  description = "Region name, or the literal \"global\" (global EXTERNAL only)."
  type        = string

  validation {
    condition     = var.scope != "global" || var.type == "EXTERNAL"
    error_message = "Global addresses are EXTERNAL only — global INTERNAL ranges belong to private_services_access."
  }
}

variable "type" {
  description = "EXTERNAL (default; value GCP-assigned) or INTERNAL (subnet-bound, optionally pinned)."
  type        = string
  default     = "EXTERNAL"

  validation {
    condition     = contains(["EXTERNAL", "INTERNAL"], var.type)
    error_message = "type must be EXTERNAL or INTERNAL."
  }
}

variable "subnetwork" {
  description = "Subnet self link — REQUIRED for INTERNAL, forbidden for EXTERNAL."
  type        = string
  default     = null

  validation {
    condition     = (var.type == "INTERNAL") == (var.subnetwork != null)
    error_message = "INTERNAL addresses require a subnetwork; EXTERNAL addresses must not carry one."
  }
}

variable "address" {
  description = "Pinned IPv4 value (INTERNAL only) — omit and GCP picks from the subnet."
  type        = string
  default     = null

  validation {
    condition     = var.address == null || var.type == "INTERNAL"
    error_message = "Only INTERNAL addresses can pin a value — EXTERNAL values are GCP-assigned (read back in outputs)."
  }
}

variable "purpose" {
  description = "INTERNAL purpose opinion: GCE_ENDPOINT (provider default) or SHARED_LOADBALANCER_VIP (multiple forwarding rules share the VIP — active/active NVA)."
  type        = string
  default     = null

  validation {
    # ternary = the lazy form (|| does not short-circuit on null)
    condition     = var.purpose == null ? true : contains(["GCE_ENDPOINT", "SHARED_LOADBALANCER_VIP"], var.purpose)
    error_message = "purpose must be GCE_ENDPOINT or SHARED_LOADBALANCER_VIP."
  }
}

variable "ip_version" {
  description = "GLOBAL EXTERNAL only: IPV4 (default) or IPV6 (v6 LB frontend). Regional/internal ignore it (always v4 today)."
  type        = string
  default     = "IPV4"

  validation {
    condition     = contains(["IPV4", "IPV6"], var.ip_version)
    error_message = "ip_version must be IPV4 or IPV6."
  }
}

variable "description" {
  description = "Optional description."
  type        = string
  default     = ""
}
