variable "type" {
  description = "Policy flavor: hierarchical | global | regional."
  type        = string

  validation {
    condition     = contains(["hierarchical", "global", "regional"], var.type)
    error_message = "type must be hierarchical, global, or regional."
  }
}

variable "tier" {
  description = <<-EOT
    Which stage is calling. The module ENFORCES what `mode` that tier is
    allowed to use:

      shared    (tier 1) -> create ONLY  — the container tier; it OWNS policies
                            (hierarchical containers + plain guardrails, G2)
      policy    (tier 6) -> create (its OWN global/regional network policies —
                            networks[] rides the policy doc) OR update
                            (rules onto a tier-1 HIERARCHICAL policy by
                            numeric id, and ONLY hierarchical — the G1/G2
                            mode redraw, BACKLOG tier-6 entry)

    The fabric (tier 2, create-or-update) and appliance (tier 5,
    attach-only) rows were RETIRED 2026-08-14 (P3): both folded into tier
    6, which owns network policies end-to-end (single ownership — the §4c
    incident history lives in DESIGN-DOCTRINE §4c).

    ⚠ mode is REQUIRED of the caller in every tier, never defaulted and
    never a const in the variable — a default would SUPPLY the value rather
    than have the author state it, and the behaviour differs per tier, so a
    reader cannot infer it from the file. The tier decides what is LEGAL;
    the author still writes which one they mean.
  EOT
  type        = string
  validation {
    condition     = contains(["shared", "policy"], var.tier)
    error_message = "tier must be shared | policy (fabric and appliance retired to tier 6 — P3, 2026-08-14)."
  }
}

variable "mode" {
  description = "create = new policy born in this stage (global/regional only; EXPLICIT name, full priority space). update = rules attached to an EXISTING policy created in an earlier tier (by name; hierarchical by numeric id). Priority is ENFORCEMENT ORDER, not a tier band — the full GCP range is legal in both modes."
  type        = string

  validation {
    condition     = contains(["create", "update"], var.mode)
    error_message = "mode must be create or update."
  }
  validation {
    condition     = var.tier == "policy" ? true : var.mode == "create"
    error_message = "This tier may not use that mode: tier 1 (shared) is create-only — it OWNS policies. Only tier 6 (policy) may choose (create its own network policies, or update tier-1 hierarchical ones)."
  }

  # Tier-6 G1 redraw (BACKLOG tier-6 entry): tier 6 UPDATE is HIERARCHICAL
  # ONLY. Its own network policies are create-mode in the same state, and a
  # tier-6 update onto another tier's global/regional policy would recreate
  # the cross-writer shape the redraw retires (tier-5 attach-only + fabric
  # rule-writing both fold into 6).
  validation {
    condition     = !(var.tier == "policy" && var.mode == "update" && var.type != "hierarchical")
    error_message = "Tier 6 (policy) update-mode is HIERARCHICAL-ONLY (G1): global/regional network policies are CREATED at tier 6 (mode = create, networks[] on the policy doc), never attached to from it."
  }

  validation {
    condition     = !(var.mode == "create" && var.type == "hierarchical")
    error_message = "Hierarchical policies are TIER-0 content (org/folder governance); the fabric stage may only UPDATE them (add/remove rules by numeric id)."
  }
}

variable "policy" {
  description = "mode=update: RENDERED name of the existing tier-0 policy (hierarchical: its NUMERIC id — GCP generates it; no name lookup exists; tier-0 outputs publish it). mode=create: the EXPLICIT name for the new policy (tier-1 policies require explicit naming — user decision)."
  type        = string

  validation {
    condition     = var.type == "hierarchical" ? can(regex("^[0-9]+$", var.policy)) : can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.policy))
    error_message = "policy must be the numeric id for hierarchical (update-only), or an RFC1035 name for global/regional."
  }
}

variable "description" {
  description = "create only: description of the new policy."
  type        = string
  default     = ""
}

variable "project_id" {
  description = "global/regional only: project of the (new or existing) policy."
  type        = string
  default     = null
}

variable "region" {
  description = "regional only: long-form region."
  type        = string
  default     = null

  validation {
    condition     = (var.type == "regional") == (var.region != null)
    error_message = "region must be set exactly when type = regional."
  }
}

variable "rules" {
  description = "Rules keyed by priority (string). Any rule content (this stage is a full management plane); source_networks/target_networks accept caller-resolved VPC self links. Priority is enforcement order in BOTH modes — there is no band restriction."
  type = map(object({
    priority                        = number
    description                     = optional(string)
    direction                       = optional(string, "INGRESS")
    action                          = string
    source_ranges                   = optional(list(string), [])
    destination_ranges              = optional(list(string), [])
    source_address_groups           = optional(list(string), [])
    destination_address_groups      = optional(list(string), [])
    source_fqdns                    = optional(list(string), [])
    destination_fqdns               = optional(list(string), [])
    source_region_codes             = optional(list(string), [])
    destination_region_codes        = optional(list(string), [])
    source_threat_intelligence      = optional(list(string), [])
    destination_threat_intelligence = optional(list(string), [])
    source_network_context          = optional(string)
    destination_network_context     = optional(string)
    source_networks                 = optional(list(string), [])
    target_networks                 = optional(list(string), [])
    target_service_accounts         = optional(list(string), [])
    source_secure_tags              = optional(list(string), [])
    target_secure_tags              = optional(list(string), [])
    tls_inspect                     = optional(bool, false)
    security_profile_group          = optional(string)
    layer4 = optional(list(object({
      protocol = string
      ports    = optional(list(string), [])
    })), [{ protocol = "all", ports = [] }])
    logging = optional(bool, false)
    enabled = optional(bool, true) # false = rule INERT (wire: disabled)
  }))
  default  = {}
  nullable = false

  # ⚠ PRIORITY IS ENFORCEMENT ORDER, NEVER A TIER MARKER. Cross-writer
  # collision in a shared policy's priority space is an ACCEPTED RISK
  # (design_and_backlog/DESIGN-DOCTRINE.md §4d) — do not re-add a band
  # gate, and do not propose uniqueness enforcement as remediation.

  validation {
    condition     = alltrue([for r in var.rules : contains(["allow", "deny", "goto_next", "apply_security_profile_group"], r.action)])
    error_message = "rule action must be allow, deny, goto_next, or apply_security_profile_group."
  }

  validation {
    condition     = alltrue([for r in var.rules : (r.action == "apply_security_profile_group") == (r.security_profile_group != null)])
    error_message = "security_profile_group must be set exactly when action = apply_security_profile_group."
  }

  validation {
    condition     = alltrue([for r in var.rules : r.security_profile_group == null || can(regex("^//networksecurity.googleapis.com/", coalesce(r.security_profile_group, "x")))])
    error_message = "SPG references must arrive as the FULL wire URL (//networksecurity.googleapis.com/...) — the calling stage resolves names to ids (the tier-6 name map or a {resolved:} pass-through)."
  }

  validation {
    condition     = var.type != "regional" || alltrue([for r in var.rules : r.action != "apply_security_profile_group" && !r.tls_inspect])
    error_message = "GCP delta: REGIONAL network firewall policies do not support firewall-endpoint inspection."
  }

  validation {
    condition     = alltrue([for r in var.rules : r.action != "goto_next" || !r.logging])
    error_message = "logging is not allowed on goto_next rules."
  }

  validation {
    condition     = var.type == "hierarchical" || alltrue([for r in var.rules : length(r.target_networks) == 0])
    error_message = "target_networks (target_resources) is HIERARCHICAL-only."
  }


  validation {
    condition = alltrue([
      for r in var.rules : r.direction == "EGRESS" ? (
        length(concat(r.destination_ranges, r.destination_address_groups, r.destination_fqdns, r.destination_region_codes, r.destination_threat_intelligence)) > 0 || r.destination_network_context != null
        ) : (
        length(concat(r.source_ranges, r.source_address_groups, r.source_fqdns, r.source_region_codes, r.source_threat_intelligence, r.source_secure_tags)) > 0 || r.source_network_context != null
      )
    ])
    error_message = "API constraint: INGRESS rules need >=1 SOURCE matcher and EGRESS rules >=1 DESTINATION matcher (layer4 alone is not a match)."
  }

  validation {
    condition = alltrue([
      for r in var.rules : r.source_network_context == null || length(concat(r.source_ranges, r.source_address_groups, r.source_fqdns, r.source_region_codes, r.source_threat_intelligence)) > 0
      ]) && alltrue([
      for r in var.rules : r.destination_network_context == null || length(concat(r.destination_ranges, r.destination_address_groups, r.destination_fqdns, r.destination_region_codes, r.destination_threat_intelligence)) > 0
    ])
    error_message = "API constraint: network context alone is not a match — a companion matcher on the same side is required (source_networks / target_service_accounts do NOT count)."
  }

  validation {
    condition = alltrue([
      for r in var.rules : alltrue([
        for ref in concat(r.source_address_groups, r.destination_address_groups) :
        var.type == "hierarchical" ? can(regex("^organizations/", ref)) : can(regex("^projects/", ref))
      ])
    ])
    error_message = "API pairing: HIERARCHICAL rules only accept ORG-parented address groups (full paths — org groups are tier-0 content); network policy rules only PROJECT-parented ones in the policy's own location."
  }

  validation {
    # GCP rejects v4+v6 mixed within one rule's ranges (verified live)
    condition = alltrue([
      for r in var.rules : (
        length([for x in concat(r.source_ranges, r.destination_ranges) : x if can(regex(":", x))]) == 0 ||
        length([for x in concat(r.source_ranges, r.destination_ranges) : x if can(regex(":", x))]) == length(concat(r.source_ranges, r.destination_ranges))
      )
    ])
    error_message = "A rule's ranges are single-family: all IPv4 or all IPv6 - never mixed (GCP rejects the rule)."
  }
}
