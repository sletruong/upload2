variable "parent" {
  description = "Tag key parent: organizations/<id> or projects/<id> (short_name is unique per parent — one 'env' key per project, even across VPCs)."
  type        = string

  validation {
    condition     = can(regex("^(organizations|projects)/[^/]+$", var.parent))
    error_message = "parent must be organizations/<id> or projects/<id>."
  }
}

variable "name" {
  description = "Tag KEY short name (explicit — the reference handle: rules say key/value)."
  type        = string
}

variable "description" {
  description = "Free-form description on the tag key."
  type        = string
  default     = ""
}

variable "network" {
  description = "OPTIONAL network restriction: '<project>/<vpc-name>' (purpose_data form). null = container-scoped tag (tier 0: org, or project-wide). Set = network-bound (fabric-nested; PROJECT parents only — org tags cannot be network-bound)."
  type        = string
  default     = null

  validation {
    condition     = var.network == null || can(regex("^[^/]+/[^/]+$", coalesce(var.network, "x")))
    error_message = "network must be '<project>/<vpc-name>' (the GCE_FIREWALL purpose_data form)."
  }

  validation {
    condition     = var.network == null || can(regex("^projects/", var.parent))
    error_message = "Network-bound tags require a PROJECT parent (org tags cannot carry a network restriction — user-specified GCP model)."
  }
}

variable "values" {
  description = "Tag VALUES nested in their key."
  type = list(object({
    name        = string
    description = optional(string, "")
  }))

  validation {
    condition     = length(var.values) > 0
    error_message = "A firewall tag key without values matches nothing — declare at least one."
  }
}
