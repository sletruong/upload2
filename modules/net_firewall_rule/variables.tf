variable "project_id" {
  description = "The VPC's project."
  type        = string
}

variable "name" {
  description = "Rule name (explicit — the naming layer's contract). Unique per project."
  type        = string
}

variable "network" {
  description = "Network self link (caller-resolved — the ordering edge)."
  type        = string
}

variable "description" {
  description = "Rule description."
  type        = string
  default     = ""
}

variable "direction" {
  description = "INGRESS | EGRESS."
  type        = string
  default     = "INGRESS"

  validation {
    condition     = contains(["INGRESS", "EGRESS"], var.direction)
    error_message = "direction must be INGRESS or EGRESS."
  }
}

variable "action" {
  description = "allow | deny — ONE per rule (the API permits exactly one)."
  type        = string

  validation {
    condition     = contains(["allow", "deny"], var.action)
    error_message = "action must be allow or deny (classic rules have no goto_next/inspection — that's the policy tiers)."
  }
}

variable "layer4" {
  description = "Protocol/port matchers (same lexicon as policy rules)."
  type = list(object({
    protocol = string
    ports    = optional(list(string), [])
  }))
  default  = [{ protocol = "all", ports = [] }]
  nullable = false
}

variable "source_ranges" {
  description = "INGRESS sources. No implicit 0.0.0.0/0 — INGRESS rules must state their sources (ranges and/or source tags/service accounts); write 0.0.0.0/0 explicitly if you mean it."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = var.direction != "INGRESS" || length(concat(var.source_ranges, coalesce(var.source_network_tags, []), coalesce(var.source_service_accounts, []))) > 0
    error_message = "INGRESS rules need at least one source qualifier (ranges, tags, or service accounts) — write 0.0.0.0/0 explicitly if you mean it."
  }

  validation {
    condition     = var.direction == "INGRESS" || length(var.source_ranges) == 0
    error_message = "source_ranges is INGRESS-only."
  }

  validation {
    # live-harvest class: GCP rejects v4+v6 mixed within one rule's ranges
    condition = (
      length([for x in concat(var.source_ranges, var.destination_ranges) : x if can(regex(":", x))]) == 0 ||
      length([for x in concat(var.source_ranges, var.destination_ranges) : x if can(regex(":", x))]) == length(concat(var.source_ranges, var.destination_ranges))
    )
    error_message = "A rule's ranges are single-family: all IPv4 or all IPv6 - never mixed (GCP rejects the rule)."
  }
}

variable "destination_ranges" {
  description = "EGRESS destinations."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = var.direction != "EGRESS" || length(var.destination_ranges) > 0 || var.target_network_tags != null || var.target_service_accounts != null
    error_message = "EGRESS rules need destination_ranges and/or target tags/service accounts — write 0.0.0.0/0 explicitly if you mean it."
  }

  validation {
    condition     = var.direction == "EGRESS" || length(var.destination_ranges) == 0
    error_message = "destination_ranges is EGRESS-only."
  }
}

variable "source_network_tags" {
  description = "INGRESS: source instance network tags (legacy tags, not resource-manager secure tags)."
  type        = list(string)
  default     = null
}

variable "source_service_accounts" {
  description = "INGRESS: source instance service accounts."
  type        = list(string)
  default     = null
}

variable "target_network_tags" {
  description = "Instances the rule applies to, by network tag."
  type        = list(string)
  default     = null
}

variable "target_service_accounts" {
  description = "Instances the rule applies to, by service account. API: service accounts and tags are MUTUALLY EXCLUSIVE across the whole rule (any mix of source/target)."
  type        = list(string)
  default     = null

  validation {
    condition = !(
      (var.source_network_tags != null || var.target_network_tags != null) &&
      (var.source_service_accounts != null || var.target_service_accounts != null)
    )
    error_message = "API constraint: network tags and service accounts cannot be mixed in one rule (any combination of source/target)."
  }
}

variable "priority" {
  description = "Rule priority (lower wins). Classic rules evaluate AFTER the policy tiers on BEFORE_CLASSIC_FIREWALL networks (the framework opinion)."
  type        = number
  default     = 1000
}

variable "enabled" {
  description = "false = rule deployed but INERT in GCP (wire: disabled=true)."
  type        = bool
  default     = true
}

variable "logging" {
  description = "Firewall rule logging; enabled=false omits the block."
  type = object({
    enabled  = optional(bool, false)
    metadata = optional(string, "INCLUDE_ALL_METADATA")
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["INCLUDE_ALL_METADATA", "EXCLUDE_ALL_METADATA"], var.logging.metadata)
    error_message = "logging.metadata must be INCLUDE_ALL_METADATA or EXCLUDE_ALL_METADATA."
  }
}

