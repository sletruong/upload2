variable "project_id" {
  type = string
}

variable "name" {
  type        = string
  description = "Rendered channel name — the handle alert policies reference."
}

variable "description" {
  type    = string
  default = ""
}

variable "type" {
  type        = string
  description = "Provider channel type: email, pagerduty, slack, pubsub, webhook_*, ..."
}

variable "enabled" {
  type        = bool
  default     = true
  description = "A DISABLED channel silently stops delivering while every policy still references it — an alerting estate can be fully configured and fully silent."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Non-secret channel config. READABLE by anyone with monitoring.read."
}

variable "sensitive_labels" {
  type = object({
    auth_token  = optional(string)
    password    = optional(string)
    service_key = optional(string)
  })
  default     = null
  sensitive   = true
  description = "Secret channel config. Source from Secret Manager; never commit a live value."
}

variable "user_labels" {
  type    = map(string)
  default = {}
}
