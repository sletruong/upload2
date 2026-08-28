variable "project_id" {
  type        = string
  description = "The metric's project — log-based metrics are project-scoped."
}

variable "name" {
  type        = string
  description = "Metric name (explicit — the naming layer's contract)."
}

variable "description" {
  type    = string
  default = ""
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Documents say `enabled`; the provider says `disabled`. The module owns the polarity flip."
}

variable "filter" {
  type        = string
  description = "Logging filter. A filter matching nothing produces a metric that reads zero forever — indistinguishable from 'the event never happened'."
}

variable "label_extractors" {
  type        = map(string)
  default     = {}
  description = "Label name -> extractor expression (REGEXP_EXTRACT/EXTRACT over log fields). Keys must match the labels declared in metric_descriptor."
}

variable "value_extractor" {
  type        = string
  default     = null
  description = "Extractor expression producing the metric VALUE from each matching entry. Null = the metric counts entries."
}

variable "bucket_name" {
  type        = string
  default     = null
  description = "Log bucket for a bucket-scoped metric. Null = project-scoped."
}

variable "metric_descriptor" {
  type = object({
    metric_kind  = string
    value_type   = string
    unit         = optional(string)
    display_name = optional(string)
    labels = optional(list(object({
      key         = string
      value_type  = optional(string, "STRING")
      description = optional(string)
    })), [])
  })
  default     = null
  description = "Metric descriptor (kind, value type, unit, labels). Null = provider default: a DELTA/INT64 counter."
}
