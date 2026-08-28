# Derive org ID from the project when not supplied by the caller
data "google_project" "this" {
  project_id = var.project_id
}

locals {
  org_id  = coalesce(var.org_id, data.google_project.this.org_id)
  regions = toset([for k, v in var.deployments : v.region])

  # For each intercept zone, the Palo Alto deployment keys in the same region.
  # Index [0] gives a valid deployment key whose subnet is used for the forwarding rule.
  intercept_zone_backends = {
    for iz_key, iz in var.intercept_zones : iz_key =>
      [for dk, dv in var.deployments : dk if dv.region == iz.region]
  }
}

# ─── Step 1: Unmanaged Instance Groups (one per Palo Alto zone) ────────────────

resource "google_compute_instance_group" "palo" {
  for_each = var.deployments

  name      = "${var.name_prefix}-ig-${each.key}"
  zone      = each.value.zone
  project   = var.project_id
  instances = [each.value.instance_self_link]
}

# ─── Step 2: Regional Health Checks (one per region) ──────────────────────────

resource "google_compute_region_health_check" "palo" {
  for_each = local.regions

  name    = "${var.name_prefix}-hc-${each.key}"
  project = var.project_id
  region  = each.key

  tcp_health_check {
    port = var.health_check_port
  }
}

# ─── Step 3: Regional Backend Services (one per region) ───────────────────────
# One backend service per region pools ALL Palo Alto instance groups in that
# region. Every zone's forwarding rule points here for true regional distribution.

resource "google_compute_region_backend_service" "palo" {
  for_each = local.regions

  name                  = "${var.name_prefix}-bs-${each.key}"
  project               = var.project_id
  region                = each.key
  protocol              = "UDP"
  load_balancing_scheme = "INTERNAL"
  network               = var.producer_network
  health_checks         = [google_compute_region_health_check.palo[each.key].id]
  session_affinity      = "CLIENT_IP_PORT_PROTO"

  dynamic "backend" {
    for_each = [for dk, dv in var.deployments : dk if dv.region == each.key]
    content {
      group          = google_compute_instance_group.palo[backend.value].id
      balancing_mode = "CONNECTION"
    }
  }
}

# ─── Step 4: Zone-Specific Forwarding Rules ────────────────────────────────────
# One unique ILB per intercept zone — GCP requires each intercept deployment to
# reference a distinct forwarding rule; sharing is not permitted.

resource "google_compute_forwarding_rule" "palo" {
  for_each = var.intercept_zones

  name                  = "${var.name_prefix}-ilb-${each.key}"
  project               = var.project_id
  region                = each.value.region
  load_balancing_scheme = "INTERNAL"
  ip_protocol           = "UDP"
  backend_service       = google_compute_region_backend_service.palo[each.value.region].id
  subnetwork            = var.deployments[local.intercept_zone_backends[each.key][0]].subnetwork
  all_ports             = true
}

# ─── Step 5: Intercept Deployment Group ───────────────────────────────────────

resource "google_network_security_intercept_deployment_group" "this" {
  provider = google-beta

  intercept_deployment_group_id = "${var.name_prefix}-deployment-group"
  location                      = "global"
  project                       = var.project_id
  network                       = var.producer_network
}

# ─── Step 6: Intercept Deployments (one per intercept zone) ───────────────────

resource "google_network_security_intercept_deployment" "this" {
  provider = google-beta
  for_each = var.intercept_zones

  intercept_deployment_id    = "${var.name_prefix}-deployment-${each.key}"
  location                   = each.value.zone
  project                    = var.project_id
  intercept_deployment_group = google_network_security_intercept_deployment_group.this.id
  forwarding_rule            = google_compute_forwarding_rule.palo[each.key].id
}

# ─── Step 7: Intercept Endpoint Group ─────────────────────────────────────────

resource "google_network_security_intercept_endpoint_group" "this" {
  provider = google-beta

  intercept_endpoint_group_id = "${var.name_prefix}-endpoint-group"
  location                    = "global"
  project                     = var.project_id
  intercept_deployment_group  = google_network_security_intercept_deployment_group.this.id
}

# ─── Step 8: Endpoint Group Associations (one per consumer VPC) ───────────────

resource "google_network_security_intercept_endpoint_group_association" "this" {
  provider = google-beta
  for_each = var.consumer_networks

  intercept_endpoint_group_association_id = "${var.name_prefix}-assoc-${each.key}"
  location                                = "global"
  project                                 = var.project_id
  intercept_endpoint_group               = google_network_security_intercept_endpoint_group.this.id
  network                                 = each.value
}

# ─── Step 9: Security Profile ─────────────────────────────────────────────────

resource "google_network_security_security_profile" "this" {
  provider = google-beta

  name     = "${var.name_prefix}-security-profile"
  type     = "CUSTOM_INTERCEPT"
  parent   = "organizations/${local.org_id}"
  location = "global"

  custom_intercept_profile {
    intercept_endpoint_group = google_network_security_intercept_endpoint_group.this.id
  }
}

# ─── Step 10: Security Profile Group ──────────────────────────────────────────

resource "google_network_security_security_profile_group" "this" {
  provider = google-beta

  name                     = "${var.name_prefix}-profile-group"
  parent                   = "organizations/${local.org_id}"
  location                 = "global"
  custom_intercept_profile = google_network_security_security_profile.this.id
}

# ─── Step 11: Network Firewall Policy ─────────────────────────────────────────

resource "google_compute_network_firewall_policy" "this" {
  name        = "${var.name_prefix}-fw-policy"
  project     = var.project_id
  description = "NSI intercept policy — routes traffic through Palo Alto via GENEVE for inspection"
}

# ─── Step 12: Firewall Policy Rules ───────────────────────────────────────────

resource "google_compute_network_firewall_policy_rule" "this" {
  for_each = { for i, r in var.intercept_rules : tostring(i) => r }

  firewall_policy        = google_compute_network_firewall_policy.this.name
  project                = var.project_id
  priority               = each.value.priority
  direction              = each.value.direction
  action                 = "apply_security_profile_group"
  description            = each.value.description
  security_profile_group = "//networksecurity.googleapis.com/${google_network_security_security_profile_group.this.id}"

  match {
    src_ip_ranges  = each.value.direction == "INGRESS" ? each.value.src_ranges : null
    dest_ip_ranges = each.value.direction == "EGRESS" ? each.value.dest_ranges : null

    layer4_configs {
      ip_protocol = each.value.ip_protocol
    }
  }
}

# ─── Step 13: Firewall Policy Associations (one per consumer VPC) ─────────────

resource "google_compute_network_firewall_policy_association" "this" {
  for_each = var.consumer_networks

  name              = "${var.name_prefix}-policy-assoc-${each.key}"
  project           = var.project_id
  attachment_target = each.value
  firewall_policy   = google_compute_network_firewall_policy.this.id
}
