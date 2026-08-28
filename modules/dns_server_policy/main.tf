# DNS server policy — ONE resource carrying inbound + outbound + logging.
# GCP law: a network holds at most ONE server policy (the stack's cross-doc
# singleton guard enforces it plan-time; the API 4xx is the last resort).

variable "project_id" {
  description = "The policy's project."
  type        = string
}
variable "name" {
  description = "Server policy name (explicit — the naming layer's contract)."
  type        = string
}
variable "description" {
  type    = string
  default = ""
}
variable "inbound" {
  description = "enable_inbound_forwarding — payloadless GCP-real toggle."
  type        = bool
  default     = false
}
variable "outbound" {
  description = "Alternative name servers (outbound). ⚠ presence DISABLES all private/forwarding/peering-zone resolution for the bound networks (doc-law) — the stack warns on the conflict."
  type = object({
    name_servers = list(object({
      address         = string
      private_routing = optional(bool, false)
    }))
  })
  default = null
}
variable "logging" {
  description = "enable_logging — logs every DNS query from the bound networks."
  type        = bool
  default     = false
}
variable "networks" {
  description = "RESOLVED network self-link URLs (arity = unique/shared; none = doc absent)."
  type        = list(string)
}

resource "google_dns_policy" "policy" {
  project                   = var.project_id
  name                      = var.name
  description               = var.description
  enable_inbound_forwarding = var.inbound
  enable_logging            = var.logging

  dynamic "alternative_name_server_config" {
    for_each = var.outbound == null ? [] : [var.outbound]
    content {
      dynamic "target_name_servers" {
        for_each = alternative_name_server_config.value.name_servers
        content {
          ipv4_address    = target_name_servers.value.address
          forwarding_path = target_name_servers.value.private_routing ? "private" : "default"
        }
      }
    }
  }

  dynamic "networks" {
    for_each = var.networks
    content {
      network_url = networks.value
    }
  }
}
