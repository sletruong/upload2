variable "project_id" {
  description = "Project the quota preference applies to (tier-0 membership: container ID only, zero VPC references)."
  type        = string
}

variable "service" {
  description = "Service owning the quota, e.g. compute.googleapis.com, networkconnectivity.googleapis.com, dns.googleapis.com."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.googleapis\\.com$", var.service))
    error_message = "service must be a *.googleapis.com service name."
  }
}

variable "quota_id" {
  description = "Quota id as returned by the Cloud Quotas API — e.g. PEERINGS-per-VPC-Network, PerProjectPerHubActiveVpcSpokes. NOT the metric and NOT the display name; run tools/quota-report.sh to get exact ids."
  type        = string
}

variable "preferred_value" {
  description = "Requested limit. -1 means unlimited. Must exceed the current default (see known_default)."
  type        = number
}

variable "dimensions" {
  description = "Dimension map scoping the request, e.g. {region = \"us-central1\"}, {network_id = \"...\"}, {hub_id = \"...\"}. Empty = applies to all values of every dimension. Never set \"user\" or \"resource\" (API rejects). Dimension KEYS come from the quota's own `dimensions` list — a wrong key is accepted by Terraform and rejected by the API."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = length(setintersection(keys(var.dimensions), ["user", "resource"])) == 0
    error_message = "dimensions must not contain \"user\" or \"resource\" — the Cloud Quotas API rejects preferences scoped to those."
  }
}

variable "justification" {
  description = "Why this increase is needed. REQUIRED by house rule (the API allows empty): an unexplained ask is the most common rejection cause when a request escalates to human review. State the design driver and the arithmetic, e.g. '38 spoke VPCs planned by Q3; default 25 blocks onboarding at spoke 26'."
  type        = string

  validation {
    condition     = length(trimspace(var.justification)) >= 20
    error_message = "justification must be a real sentence (>= 20 chars) — it is read by a human reviewer."
  }
}

variable "contact_email" {
  description = "Email Google may contact about this request. The account must hold quota update permission on the parent."
  type        = string
  default     = null

  validation {
    condition     = var.contact_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", coalesce(var.contact_email, "x@y.z")))
    error_message = "contact_email must be a valid email address."
  }
}

variable "name" {
  description = "Preference resource name. Omit to derive <service>-<quota_id>[-<dimension values>] (stable, sorted)."
  type        = string
  default     = null
}

variable "known_default" {
  description = "The quota's current default, from the catalog. Enables the plan-time guard that rejects a request at or below the default (a no-op that still burns a review cycle). Null disables the check."
  type        = number
  default     = null
}

variable "is_fixed" {
  description = "Whether the API reports isFixed=true. Fixed quotas are NOT self-serve adjustable; the module refuses them at plan time. NOTE: fixed does not mean unraisable — many fixed quotas are still increase-eligible via a support case (QUOTA-CATALOG.md §0)."
  type        = bool
  default     = false
}

variable "ignore_safety_checks" {
  description = "Safety check to bypass, e.g. QUOTA_DECREASE_BELOW_USAGE. Only relevant to DECREASES; leave null for increases. SCHEMA NOTE: a single string in the GA provider, not a list."
  type        = string
  default     = null

  validation {
    condition = var.ignore_safety_checks == null || contains(
      ["QUOTA_SAFETY_CHECK_UNSPECIFIED", "QUOTA_DECREASE_BELOW_USAGE", "QUOTA_DECREASE_PERCENTAGE_TOO_HIGH"],
      coalesce(var.ignore_safety_checks, "QUOTA_SAFETY_CHECK_UNSPECIFIED")
    )
    error_message = "ignore_safety_checks must be QUOTA_SAFETY_CHECK_UNSPECIFIED, QUOTA_DECREASE_BELOW_USAGE, or QUOTA_DECREASE_PERCENTAGE_TOO_HIGH."
  }
}
