variable "project_id" {
  type        = string
  description = "The project whose internet-bound DNS queries are analysed. DNS Armor is PROJECT-scoped: one detector covers every VPC in the project unless excluded."
}

variable "name" {
  type        = string
  description = "Detector name (explicit — the naming layer's contract)."
}

variable "excluded_networks" {
  type        = list(string)
  default     = []
  description = <<-EOT
    VPCs to EXCLUDE from inspection, as `projects/<p>/global/networks/<n>`.
    Max 100 (GCP limit).

    ⚠ EXCLUSION IS THE ONLY SCOPING KNOB. There is no "inspect only these"
    form — a detector covers the whole project and you subtract from it.
  EOT

  validation {
    condition     = length(var.excluded_networks) <= 100
    error_message = "DNS Armor supports at most 100 excluded networks per detector."
  }

  validation {
    condition = alltrue([
      for n in var.excluded_networks : can(regex("^projects/[^/]+/global/networks/[^/]+$", n))
    ])
    error_message = "excluded_networks entries must be projects/<project>/global/networks/<name>."
  }
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels on the detector."
}
