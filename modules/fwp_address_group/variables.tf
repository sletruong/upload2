variable "address_groups" {
  description = "Address groups keyed by state identity (<target>/<name>). The reusable IP/CIDR sets firewall policy rules match on — rules reference these by RENDERED name, resolved by the caller (the reference enforces group-before-rule ordering, the fwp_ngfw pattern). parent = organizations/<id> or projects/<id> BARE container. location fixed global (firewall-policy consumption). GCP: type and capacity are IMMUTABLE (change = replace, cascading to referencing rules); items are mutable within capacity."
  type = map(object({
    name        = string
    parent      = string
    description = optional(string, "")
    type        = string
    capacity    = number
    location    = optional(string, "global")
    items       = optional(list(string), [])
    labels      = optional(map(string), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for g in var.address_groups : can(regex("^(organizations|projects)/[^/]+$", g.parent))])
    error_message = "parent must be EXACTLY organizations/<id> or projects/<id> (no folders). Pairing (API-verified): hierarchical policy rules only consume ORG-parented groups; network policies only PROJECT-parented groups in the policy's location."
  }

  validation {
    condition     = alltrue([for g in var.address_groups : contains(["IPV4", "IPV6"], g.type)])
    error_message = "type must be IPV4 or IPV6."
  }

  validation {
    condition     = alltrue([for g in var.address_groups : length(g.items) <= g.capacity])
    error_message = "items exceed the declared capacity (capacity is immutable in GCP — declare headroom up front)."
  }

  validation {
    # items must match the group's declared (immutable) family
    condition = alltrue([
      for g in var.address_groups : (
        g.type == "IPV4"
        ? length([for i in g.items : i if can(regex(":", i))]) == 0
        : length([for i in g.items : i if can(regex(":", i))]) == length(g.items)
      )
    ])
    error_message = "Address-group items must all match the group's declared type - an IPV4 group carries no colons, an IPV6 group only colon-bearing items (GCP rejects mismatches at apply; this catches them at plan)."
  }
}
