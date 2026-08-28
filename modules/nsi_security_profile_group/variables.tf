variable "project_id" {
  type        = string
  description = "Fallback parent: the SPG lands in projects/<project_id> when target is omitted."
}
variable "name" {
  type        = string
  description = "Name for BOTH the security profile and the group that wraps it (explicit — the naming layer's contract)."
}
variable "description" {
  type    = string
  default = ""
}
variable "target" {
  type        = string
  default     = null
  description = "Parent container (organizations/<id> or projects/<id>). Omit = this document's project. ⚠ ORG-PARENTED is what lets a folder/org-level firewall rule name this SPG; a project-parented SPG can only be referenced by rules in that same project."
}
variable "type" {
  type        = string
  default     = "INTERCEPT"
  description = <<-EOT
    INTERCEPT -> a CUSTOM_INTERCEPT profile (inline, can DROP)
    MIRROR    -> a CUSTOM_MIRRORING profile (a COPY, cannot block)

    ⚠ MUST MATCH the referenced endpoint group's own type — a
    CUSTOM_INTERCEPT profile cannot point at a mirroring endpoint group.
    They are different GCP resource families, not a flag on one resource.
  EOT

  validation {
    condition     = contains(["INTERCEPT", "MIRROR"], var.type)
    error_message = "type must be INTERCEPT or MIRROR."
  }
}
variable "endpoint_group" {
  type        = string
  description = "Full path of the endpoint group this profile points at. REQUIRED by the provider — custom_intercept_profile.intercept_endpoint_group has no default."
}
