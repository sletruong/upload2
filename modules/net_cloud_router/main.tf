# Cloud Router (fabric): nests under its VPC — the caller passes the resolved
# network self link, so create order is VPC-then-router and destroy order is
# router-then-VPC. NATs nest under the router (separate module; the router
# name reference is their ordering edge). BGP peers/hybrid attachments are
# stage-2 content and attach to this router by name.

# pre_existing = true: the router EXISTS and is not managed here. No data
# source — pre_existing exists so CHILDREN can attach to an unmanaged
# parent (interfaces here, NATs one module over, stage-4 sessions by
# name); no child needs an attribute from the parent, so none is read
# (design_and_backlog/DESIGN-DOCTRINE.md: data references only when
# deployment needs an element). Top-level attributes are schema-rejected
# upstream.
resource "google_compute_router" "router" {
  count       = var.pre_existing ? 0 : 1
  project     = var.project_id
  name        = var.name
  region      = var.region
  network     = var.network
  description = var.description

  dynamic "bgp" {
    for_each = var.bgp != null ? [var.bgp] : []
    content {
      asn                = bgp.value.asn
      advertise_mode     = bgp.value.advertise_mode
      advertised_groups  = bgp.value.advertised_groups
      keepalive_interval = bgp.value.keepalive_interval

      dynamic "advertised_ip_ranges" {
        for_each = bgp.value.advertised_ip_ranges
        content {
          range       = advertised_ip_ranges.value.range
          description = advertised_ip_ranges.value.description
        }
      }
    }
  }
}

# Primary interfaces first; redundant partners second (GCP requires the
# referenced primary to exist — parallel sibling creation would race).
resource "google_compute_router_interface" "primary" {
  for_each = { for k, i in var.interfaces : k => i if i.redundant_interface == null }

  project = var.project_id
  region  = var.region
  router  = var.name
  name    = each.key

  subnetwork         = each.value.subnetwork
  private_ip_address = each.value.private_address

  depends_on = [google_compute_router.router]
}

resource "google_compute_router_interface" "redundant" {
  for_each = { for k, i in var.interfaces : k => i if i.redundant_interface != null }

  project = var.project_id
  region  = var.region
  router  = var.name
  name    = each.key

  subnetwork          = each.value.subnetwork
  private_ip_address  = each.value.private_address
  redundant_interface = each.value.redundant_interface

  depends_on = [google_compute_router_interface.primary, google_compute_router.router]
}

# The router's BGP policy library. Sessions subscribe by name from the
# stage that owns them.
resource "google_compute_router_route_policy" "policy" {
  for_each = var.route_policies

  project = var.project_id
  region  = var.region
  router  = var.name
  name    = each.key
  # lexicon: IMPORT/EXPORT in config; the API wants the long enum
  type = "ROUTE_POLICY_TYPE_${each.value.type}"

  dynamic "terms" {
    for_each = each.value.terms
    content {
      priority = terms.value.priority
      match {
        expression = terms.value.match
      }
      dynamic "actions" {
        for_each = terms.value.actions
        content {
          expression = actions.value
        }
      }
    }
  }

  depends_on = [google_compute_router.router]
}
