/**
 * Appliance ILB — internal passthrough NLB frontend for an NVA fleet
 * (stage 5-appliance): VIP claim + regional health check + backend service
 * + forwarding rule. FRONTEND-ONLY — steering is the routes/ family.
 *
 * The frontend legally exists with ZERO backends (the membership contract:
 * claim the VIP early, attach at cutover) — backends arrive from the
 * stack's partition IGs. HC / backend service / forwarding rule all carry
 * the document name (separate GCP namespaces; 1:1 plumbing rides the
 * connection, no derived suffixes).
 *
 * STEERING LIVES ELSEWHERE: in-estate routes join
 * this frontend from 5-appliance/routes/ — the stack resolves the join to
 * this module's `address` output, whose depends_on(forwarding rule) IS the
 * order-of-operations edge (LB-before-route, route-gone-before-LB-delete).
 */

data "google_compute_address" "vip" {
  project = var.project_id
  region  = var.region
  name    = var.address

  lifecycle {
    # Purpose law (Google's VPC static routes documentation, next-hop
    # considerations): a next-hop ILB VIP must be UNIQUE to its forwarding
    # rule — SHARED_LOADBALANCER_VIP addresses on next-hop duty are
    # SILENTLY DROPPED by the dataplane. Routes present ⇒ GCE_ENDPOINT
    # only; routes absent ⇒ shared VIPs stay legal (the multi-fwd-rule
    # active/active case the address contract anticipates).
    postcondition {
      condition = var.next_hop_duty ? self.purpose == "GCE_ENDPOINT" : (
        contains(["SHARED_LOADBALANCER_VIP", "GCE_ENDPOINT"], self.purpose)
      )
      error_message = "ILB '${var.name}': address '${var.address}' purpose '${self.purpose}' is illegal for this duty — next-hop frontends (a routes/ doc joins this frontend) require GCE_ENDPOINT (SHARED_LOADBALANCER_VIP is silently dropped on next-hop paths); join-less frontends accept either."
    }
  }
}

resource "google_compute_region_health_check" "this" {
  project = var.project_id
  region  = var.region
  name    = var.name

  check_interval_sec  = var.health_check.interval
  timeout_sec         = coalesce(var.health_check.timeout, var.health_check.interval)
  healthy_threshold   = var.health_check.healthy_threshold
  unhealthy_threshold = var.health_check.unhealthy_threshold

  dynamic "tcp_health_check" {
    for_each = var.health_check.protocol == "TCP" ? [1] : []
    content {
      port = var.health_check.port
    }
  }
  dynamic "http_health_check" {
    for_each = var.health_check.protocol == "HTTP" ? [1] : []
    content {
      port = var.health_check.port
      # ⚠ WITHOUT request_path THE PROBE HITS "/" — which appliances do not
      # serve, so the check fails while the port is plainly open. PAN-OS
      # exposes an unauthenticated page at /unauth/php/health.php.
      request_path = try(var.health_check.request_path, null)
    }
  }
  dynamic "https_health_check" {
    for_each = var.health_check.protocol == "HTTPS" ? [1] : []
    content {
      port = var.health_check.port
      # ⚠ WITHOUT request_path THE PROBE HITS "/" — which appliances do not
      # serve, so the check fails while the port is plainly open. PAN-OS
      # exposes an unauthenticated page at /unauth/php/health.php.
      request_path = try(var.health_check.request_path, null)
    }
  }
}

resource "google_compute_region_backend_service" "this" {
  project = var.project_id
  region  = var.region
  name    = var.name

  load_balancing_scheme = "INTERNAL"
  # L3_DEFAULT frontends require an UNSPECIFIED backend protocol
  protocol         = var.protocol == "L3_DEFAULT" ? "UNSPECIFIED" : var.protocol
  network          = var.network
  session_affinity = var.session_affinity

  # Zonal affinity — omitted entirely when null (GCP default DISABLED).
  # ⚠ Supported with NSI (measured 2026-08-14; see variable description).
  dynamic "network_pass_through_lb_traffic_policy" {
    for_each = var.zonal_affinity == null ? [] : [var.zonal_affinity]
    content {
      zonal_affinity {
        spillover       = network_pass_through_lb_traffic_policy.value.spillover
        spillover_ratio = network_pass_through_lb_traffic_policy.value.spillover_ratio
      }
    }
  }
  health_checks = [google_compute_region_health_check.this.id]

  dynamic "backend" {
    for_each = var.backends
    content {
      group    = backend.value.group
      failover = backend.value.failover
      # INTERNAL backend services accept only CONNECTION — the API rejects
      # the provider's UTILIZATION default (400, verified live)
      balancing_mode = "CONNECTION"
    }
  }
}

resource "google_compute_forwarding_rule" "this" {
  project = var.project_id
  region  = var.region
  name    = var.name

  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.this.id
  network               = var.network
  subnetwork            = var.subnetwork
  ip_address            = data.google_compute_address.vip.self_link
  ip_protocol           = var.protocol
  all_ports             = length(var.ports) == 0 ? true : null
  ports                 = length(var.ports) > 0 ? var.ports : null
  allow_global_access   = var.global_access
}
