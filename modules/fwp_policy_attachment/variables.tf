variable "type" {
  description = "global | regional — which network-policy flavor is being attached. (Hierarchical policies attach to org/folder containers in tier 0, never to VPCs.)"
  type        = string

  validation {
    condition     = contains(["global", "regional"], var.type)
    error_message = "type must be global or regional."
  }
}

variable "name" {
  description = "Association name — PLUMBING, not a contract surface: the caller derives it from the network name (unique per policy: a policy attaches to a network at most once)."
  type        = string
}

variable "project_id" {
  description = "Project of the policy + network."
  type        = string
}

variable "policy" {
  description = "The firewall policy: rendered NAME for tier-0 policies (exist by stage order), or the caller-resolved ID for fabric-created ones (the reference is the ordering edge)."
  type        = string
}

variable "network" {
  description = "Network self link (caller-resolved from the enclosing VPC — the ordering edge)."
  type        = string
}

variable "region" {
  description = "regional only: the policy's region."
  type        = string
  default     = null

  validation {
    condition     = (var.type == "regional") == (var.region != null)
    error_message = "region must be set exactly when type = regional."
  }
}
