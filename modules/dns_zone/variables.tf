variable "project_id" {
  description = "Project the zone lives in (the doc's EFFECTIVE project — inherited or stated)."
  type        = string
}

variable "name" {
  description = "Zone resource name (explicit — the naming layer's contract)."
  type        = string
}

variable "dns_name" {
  description = "DNS origin, trailing dot (e.g. googleapis.com.)."
  type        = string

  validation {
    condition     = endswith(var.dns_name, ".")
    error_message = "dns_name must be fully qualified (trailing dot)."
  }
}

variable "description" {
  description = "Zone description."
  type        = string
  default     = ""
}

variable "networks" {
  description = "RESOLVED network self-link URLs this private zone is visible to (caller resolves the {explicit|resolved} union against the doc's effective project)."
  type        = list(string)

  validation {
    condition     = length(var.networks) > 0
    error_message = "A private zone with zero networks is invisible — bind at least one (public zones are out of scope for 3-dns)."
  }
}

variable "records" {
  description = "Record sets for an authoritative private zone. XOR with forwarding/peering (zone kind is structural)."
  type = list(object({
    name   = string
    type   = string
    ttl    = optional(number, 300)
    values = list(string)
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.records : endswith(r.name, ".")])
    error_message = "Record names must be fully qualified (trailing dot)."
  }
}

variable "forwarding" {
  description = "Forwarding-zone payload: targets [{address, private_routing}]. Doc-law: all addresses XOR one FQDN — this module carries the address form."
  type = object({
    targets = list(object({
      address         = string
      private_routing = optional(bool, false)
    }))
  })
  default = null
}

variable "peering" {
  description = "Peering-zone payload: RESOLVED producer network self-link URL."
  type = object({
    target_network = string
  })
  default = null
}

variable "labels" {
  description = "Labels on the zone."
  type        = map(string)
  default     = {}
}
