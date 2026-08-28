variable "project_id" {
  type        = string
  description = "CONSUMER-side project. May differ from the deployment group's project — the supported multi-tenant shape."
}

variable "name" { type = string }

variable "description" {
  type    = string
  default = ""
}

variable "type" {
  type        = string
  default     = "INTERCEPT"
  description = <<-EOT
    WHICH RESOURCE FAMILY this group is:
      INTERCEPT -> google_network_security_intercept_endpoint_group
      MIRROR    -> google_network_security_mirroring_endpoint_group

    These are DIFFERENT GCP RESOURCES, not one resource with a flag.
    Intercept is INLINE and can DROP; mirroring is a COPY that detects and
    cannot block. The provider expresses the fork as two resource types, so
    the document must state which it means (.claude/LEXICON.md §1, §7).
  EOT

  validation {
    condition     = contains(["INTERCEPT", "MIRROR"], var.type)
    error_message = "type must be INTERCEPT or MIRROR."
  }
}

variable "deployment_group" {
  type        = string
  description = "Producer deployment group path. Exactly ONE per endpoint group."
}

variable "associations" {
  description = <<-EOT
    CONSUMER VPCs to inspect — keyed by document name, value is the network
    path. The association and its consumer VPC MUST share a project; the
    endpoint group need not.
  EOT
  type        = map(string)
  default     = {}
}

variable "labels" {
  type    = map(string)
  default = {}
}
