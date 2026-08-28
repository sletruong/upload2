# Private Services Access (fabric): reserved VPC_PEERING ranges + the ONE
# servicenetworking connection they feed + the peering's route-exchange
# config. Design choices (RULED 2026-08-15): **DELETE deletion policy is
# the design** — we do not abandon resources; a teardown must actually tear
# down. ABANDON is legacy/discouraged (leaves an unmanaged connection).
# Known cost, measured live: the delete intermittently wedges on GCP's
# producer-tenancy GC race (~1 in 4 on 2026-08-15; one tenancy stuck 6h+
# after consumer deletion) — that is a GCP defect to WAIT OUT or triage
# with support, never a reason to abandon. Plus a pacing sleep (peering op
# — provider throttle bug) and the peering_routes_config. IPv4-only.
# The NCC producer_vpc spoke exports these producer ranges into a hub.

resource "time_sleep" "pacing" {
  create_duration = "5s"
}

resource "google_compute_global_address" "range" {
  for_each = { for r in var.ranges : r.name => r }

  project      = var.project_id
  name         = each.value.name
  purpose      = "VPC_PEERING"
  address_type = "INTERNAL"
  # Manual: exact block; Automatic: address omitted, GCP picks a free block
  address       = each.value.ipv4_cidr != null ? split("/", each.value.ipv4_cidr)[0] : null
  prefix_length = each.value.ipv4_cidr != null ? tonumber(split("/", each.value.ipv4_cidr)[1]) : each.value.ipv4_prefix_length
  network       = var.network
}

resource "google_service_networking_connection" "connection" {
  network                 = var.network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [for r in google_compute_global_address.range : r.name]
  deletion_policy         = var.deletion_policy == "abandon" ? "ABANDON" : null # delete = the default behavior (verified live)

  depends_on = [time_sleep.pacing]
}

resource "google_compute_network_peering_routes_config" "routes" {
  project = var.project_id
  network = element(reverse(split("/", var.network)), 0)
  peering = google_service_networking_connection.connection.peering

  export_custom_routes = var.export_custom_routes
  import_custom_routes = var.import_custom_routes
}
