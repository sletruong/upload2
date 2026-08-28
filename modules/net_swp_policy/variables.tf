variable "project_id" {
  type        = string
  description = "The policy's project."
}
variable "name" {
  type        = string
  description = "Policy name (explicit — the naming layer's contract)."
}
variable "region" {
  type        = string
  description = "REGIONAL resource. Must match the region of every gateway that attaches this policy and every URL list its rules reference."
}
variable "description" {
  type    = string
  default = ""
}
variable "tls_inspection_policy" {
  type        = string
  default     = null
  description = "TLS inspection policy path. Omit = NO TLS inspection: rules then see only SNI/host, never URL PATHS. A path-scoped allowlist silently degrades to host-scoped without it."
}
variable "rules" {
  description = <<-EOT
    Ordered proxy rules. `session_matcher` is CEL over connection attributes
    (host, source, destination); `application_matcher` is CEL over L7 and is
    where a URL LIST is referenced.

    ⚠ FIRST MATCH WINS BY PRIORITY. An `ALLOW` on a broad session_matcher at
    a low priority number makes every narrower rule beneath it dead config.
  EOT
  type = map(object({
    priority               = number
    session_matcher        = string
    application_matcher    = optional(string)
    basic_profile          = string # ALLOW | DENY
    enabled                = optional(bool, true)
    tls_inspection_enabled = optional(bool, false)
    description            = optional(string, "")
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.rules) : contains(["ALLOW", "DENY"], r.basic_profile)])
    error_message = "basic_profile must be ALLOW or DENY."
  }

  validation {
    condition     = length(distinct([for r in values(var.rules) : r.priority])) == length(var.rules)
    error_message = "Two SWP rules share a priority — evaluation order would be undefined."
  }
}
