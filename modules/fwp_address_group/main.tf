# Address groups (tier 0): reusable IP/CIDR sets consumed by firewall policy
# rules (src/dest_address_groups). Rules DEPEND on this module — the caller
# resolves rendered names to the ids output here, and that reference IS the
# group-before-rule ordering GCP requires.

resource "google_network_security_address_group" "group" {
  for_each = var.address_groups

  name        = each.value.name
  parent      = each.value.parent
  location    = each.value.location
  description = each.value.description
  type        = each.value.type
  capacity    = each.value.capacity
  items       = each.value.items
  labels      = each.value.labels
}
