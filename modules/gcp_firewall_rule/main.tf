resource "google_compute_firewall" "rules" {
  for_each    = var.firewall_rules
  name        = each.key
  description = each.value.description
  direction   = each.value.direction
  network     = var.network_name
  project     = var.project_id

  ## This logic handles implicit 0/0 when no source_ranges, source_tags or source_service_accounts are specified
  source_ranges = each.value.direction == "INGRESS" ? (
    length(each.value.ranges) > 0
    ? each.value.ranges
    : (
      (each.value.source_tags != null || each.value.source_service_accounts != null)
      ? null
      : ["0.0.0.0/0"]
    )
  ) : null

  ## This logic handles implicit 0/0 when no destination_ranges, target_tags or target_service_accounts are specified
  destination_ranges = each.value.direction == "EGRESS" ? (
    length(each.value.ranges) > 0
    ? each.value.ranges
    : (
      (each.value.target_tags != null || each.value.target_service_accounts != null)
      ? null
      : ["0.0.0.0/0"]
    )
  ) : null

  source_tags             = each.value.source_tags
  source_service_accounts = each.value.source_service_accounts
  target_tags             = each.value.target_tags
  target_service_accounts = each.value.target_service_accounts
  priority                = each.value.priority

  dynamic "log_config" {
    for_each = coalesce(each.value.log_config, [])
    content {
      metadata = log_config.value.metadata
    }
  }

  dynamic "allow" {
    for_each = lookup(each.value, "allow", [])
    content {
      protocol = allow.value.protocol
      ports    = lookup(allow.value, "ports", null)
    }
  }

  dynamic "deny" {
    for_each = lookup(each.value, "deny", [])
    content {
      protocol = deny.value.protocol
      ports    = lookup(deny.value, "ports", null)
    }
  }
}
