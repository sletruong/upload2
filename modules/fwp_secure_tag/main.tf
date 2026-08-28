# Secure tag key + values (fabric): resource-manager tags with purpose
# GCE_FIREWALL — NETWORK-BOUND via purpose_data (the ground truth that moved
# this family from tier 0 into the VPC document: the nesting supplies the
# network). Policy rules reference values as key/value (resolved same-state
# to tagValues/N) or {resolved: tagValues/N} for pre-existing tags.

resource "google_tags_tag_key" "key" {
  parent      = var.parent
  short_name  = var.name
  description = var.description

  purpose      = "GCE_FIREWALL"
  purpose_data = var.network == null ? null : { network = var.network }
}

resource "google_tags_tag_value" "value" {
  for_each = { for v in var.values : v.name => v }

  parent      = google_tags_tag_key.key.id
  short_name  = each.key
  description = each.value.description
}
