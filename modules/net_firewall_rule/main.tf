# Classic VPC firewall rule (fabric): the layer that evaluates AFTER the
# policy tiers on BEFORE_CLASSIC_FIREWALL networks. Lexicon matches the
# policy-rule surface (action + layer4 + source/destination_ranges).
# Design intents: exactly ONE action per rule (allow XOR deny — the API
# permits exactly one), no implicit 0.0.0.0/0 (write it explicitly if you
# mean it), and direction-explicit range fields (source_/destination_).

resource "google_compute_firewall" "rule" {
  project     = var.project_id
  network     = var.network
  name        = var.name
  description = var.description
  direction   = var.direction
  priority    = var.priority
  disabled    = !var.enabled # lexicon owns the polarity flip

  source_ranges      = var.direction == "INGRESS" && length(var.source_ranges) > 0 ? var.source_ranges : null
  destination_ranges = var.direction == "EGRESS" && length(var.destination_ranges) > 0 ? var.destination_ranges : null

  source_tags             = var.source_network_tags
  source_service_accounts = var.source_service_accounts
  target_tags             = var.target_network_tags
  target_service_accounts = var.target_service_accounts

  dynamic "allow" {
    for_each = var.action == "allow" ? var.layer4 : []
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  dynamic "deny" {
    for_each = var.action == "deny" ? var.layer4 : []
    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }

  dynamic "log_config" {
    for_each = var.logging.enabled ? [1] : []
    content {
      metadata = var.logging.metadata
    }
  }
}
