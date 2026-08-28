# Stage 8 alert-policy module INPUT types — the typed mirror of the doc
# grammar (alert-policies.schema.json).
#
# SILENT-DROP LAW: every doc field must appear HERE and in the stack
# passthrough, or Terraform's object type coercion strips it without a
# whisper. That failure is especially bad in this tier: a dropped
# `scope_by` key yields a policy that applies cleanly, reads green, and
# never fires.

variable "project_id" { type = string }

variable "name" {
  type        = string
  description = "Rendered policy name. The module appends a severity suffix when one document emits a warn/critical pair."
}

variable "description" {
  type        = string
  default     = ""
  description = "Renders to documentation.content — what an operator reads at 3am."
}

variable "enabled" {
  type    = bool
  default = true
}

variable "severity" {
  type        = string
  default     = null
  description = "critical | warning | info. Provider wants uppercase; the module owns the case flip."
}

variable "notification_channels" {
  type        = list(string)
  default     = []
  description = "Resolved channel IDs. An EMPTY list is legal and meaningful — silence must be declared."
}

variable "auto_close" {
  type        = string
  default     = null
  description = "Duration (e.g. \"1800s\") with no matching data before an open incident auto-closes. Null = provider default (7 days)."
}

variable "renotify_interval" {
  type        = string
  default     = null
  description = "Re-notification period (e.g. \"86400s\") while a condition stays open. Null = notify only on open/close."
}

# ── The condition: exactly one kind is non-null (schema enforces XOR) ─────

variable "threshold" {
  description = <<-EOT
    A `requires:` block, already resolved by the stack into provider terms.
    `filter` is the fully-rendered Monitoring filter (metric type + scope_by);
    `denominator_filter` is set only for ratio conditions (native support —
    no MQL needed). `comparison`/`threshold_value` come from whichever
    threshold band this policy instance represents.
  EOT
  type = object({
    filter               = string
    comparison           = string
    threshold_value      = optional(number)
    duration             = string
    alignment_period     = optional(string, "300s")
    per_series_aligner   = optional(string)
    cross_series_reducer = optional(string)
    group_by_fields      = optional(list(string), [])
    denominator_filter   = optional(string)
    denominator_aligner  = optional(string)
    denominator_reducer  = optional(string)
  })
  default = null
}

variable "absent" {
  description = "A `absent:` block. The only condition kind that catches a VANISHED emitter — a threshold cannot fire on a missing series."
  type = object({
    filter               = string
    duration             = string
    alignment_period     = optional(string, "300s")
    per_series_aligner   = optional(string)
    cross_series_reducer = optional(string)
    group_by_fields      = optional(list(string), [])
  })
  default = null
}

variable "log_match" {
  description = "A `log_match:` block — the home for what the metric tier structurally cannot do (route identity, config-change events)."
  type = object({
    filter           = string
    label_extractors = optional(map(string), {})
  })
  default = null
}

variable "user_labels" {
  type        = map(string)
  default     = {}
  description = "Labels on the policy resource itself — not rendered into notifications."
}
