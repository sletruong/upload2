# Private managed zone, typed by kind: exactly one of records / forwarding /
# peering (the stack enforces the XOR before calling; the API would also
# reject a mixed zone). Records are separate resources keyed name/type.

resource "google_dns_managed_zone" "zone" {
  project     = var.project_id
  name        = var.name
  dns_name    = var.dns_name
  description = var.description
  visibility  = "private"
  labels      = var.labels

  private_visibility_config {
    dynamic "networks" {
      for_each = var.networks
      content {
        network_url = networks.value
      }
    }
  }

  dynamic "forwarding_config" {
    for_each = var.forwarding == null ? [] : [var.forwarding]
    content {
      dynamic "target_name_servers" {
        for_each = forwarding_config.value.targets
        content {
          ipv4_address    = target_name_servers.value.address
          forwarding_path = target_name_servers.value.private_routing ? "private" : "default"
        }
      }
    }
  }

  dynamic "peering_config" {
    for_each = var.peering == null ? [] : [var.peering]
    content {
      target_network {
        network_url = peering_config.value.target_network
      }
    }
  }
}

resource "google_dns_record_set" "record" {
  for_each = { for r in var.records : "${r.name}/${r.type}" => r }

  project      = var.project_id
  managed_zone = google_dns_managed_zone.zone.name
  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.values
}
