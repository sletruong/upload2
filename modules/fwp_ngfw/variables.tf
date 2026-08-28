variable "security_profile_groups" {
  description = "Security profile GROUP definitions keyed by identity token. A group links one profile per type (threat_prevention / url_filtering — at least one); profiles are created here with the caller-resolved names. Groups do NOT reference endpoints — GCP has no SPG<->endpoint API link (endpoint->VPC associations are stage-1). parent = organizations/<id> or projects/<id> BARE container string. signature_overrides is the framework lexicon for the provider's threat_overrides (keyed by threat/signature id)."
  type = map(object({
    name        = string
    parent      = string
    description = optional(string, "")
    profiles = object({
      threat_prevention = optional(object({
        name                = string
        severity_overrides  = optional(map(string), {})
        signature_overrides = optional(map(string), {})
        antivirus_overrides = optional(map(string), {})
      }))
      url_filtering = optional(object({
        name = string
        url_filters = list(object({
          priority = number
          action   = string
          urls     = list(string)
        }))
      }))
    })
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for g in var.security_profile_groups : can(regex("^(organizations|projects)/[^/]+$", g.parent))])
    error_message = "parent must be EXACTLY organizations/<id> or projects/<id> — no /locations suffix (the provider appends it)."
  }

  validation {
    condition     = alltrue([for g in var.security_profile_groups : g.profiles.threat_prevention != null || g.profiles.url_filtering != null])
    error_message = "Each group needs at least one profile (threat_prevention and/or url_filtering)."
  }

  validation {
    condition = alltrue(flatten([
      for g in var.security_profile_groups : [
        for f in try(coalesce(try(g.profiles.url_filtering.url_filters, null), []), []) : contains(["ALLOW", "DENY"], f.action)
      ]
    ]))
    error_message = "url_filters action must be ALLOW or DENY."
  }
}

variable "endpoints" {
  description = "NGFW firewall endpoints keyed by identity (<function>:<zone> or explicit name). ZONAL; parent = organizations/<id> OR projects/<id> (both API-supported, provider >= 7.x); requires billing_project_id (the documented v1 gotcha: provider also needs user_project_override/billing_project for org-scoped networksecurity calls)."
  type = map(object({
    name               = string
    parent             = string
    billing_project_id = string
    zone               = string
    labels             = optional(map(string), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for e in var.endpoints : can(regex("^(organizations|projects)/[^/]+$", e.parent))])
    error_message = "endpoint parent must be organizations/<id> or projects/<id>."
  }
}
