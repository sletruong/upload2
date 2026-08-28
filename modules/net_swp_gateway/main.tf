# Secure Web Proxy gateway — the actual proxy VIP.
#
# REACHABILITY: three documented modes, and PSC IS ONE OF THEM.
#   1. same-VPC / shared VPC / peering / NCC — plain routing to the VIP
#   2. PSC SERVICE ATTACHMENT — publish this gateway, consumers create an
#      endpoint in their own VPC (modules/net_psc_service_attachment)
#   3. next-hop mode — routes steer traffic, clients unaware
#
# PSC PUBLISHING IS SUPPORTED: service_attachment.target_service is "the
# URL of a service serving the endpoint" — a forwarding rule is the common
# case, not the only one. The gateway URI goes in directly:
#   //networkservices.googleapis.com/projects/<p>/locations/<r>/gateways/<n>
# (see Google's Secure Web Proxy documentation).
#
# ROUTING MODE:
#   EXPLICIT_ROUTING_MODE  clients set a proxy URL (http_proxy / browser)
#   NEXT_HOP_ROUTING_MODE  traffic is steered by route, clients unaware
# This module pins EXPLICIT for two reasons: it is the mode whose contract is
# a STABLE ADDRESS clients configure against, and — decisively — GOOGLE
# STATES PSC PUBLISHING DOES NOT SUPPORT NEXT-HOP MODE (Google's Secure
# Web Proxy service-attachment deployment documentation). A next-hop
# gateway cannot be published through a service attachment at all.
#
# ⚠ delete_swg_autogen_router_on_destroy: SWP silently creates a router for
# itself. Left behind, it blocks the VPC's own teardown later with an error
# that names a resource nobody declared.
resource "google_network_services_gateway" "this" {
  project     = var.project_id
  name        = var.name
  location    = var.region
  description = var.description

  type         = "SECURE_WEB_GATEWAY"
  routing_mode = "EXPLICIT_ROUTING_MODE"

  network    = var.network
  subnetwork = var.subnetwork
  addresses  = length(var.addresses) > 0 ? var.addresses : null
  ports      = var.ports

  gateway_security_policy = var.gateway_security_policy
  certificate_urls        = length(var.certificate_urls) > 0 ? var.certificate_urls : null
  scope                   = var.scope
  labels                  = var.labels

  delete_swg_autogen_router_on_destroy = true
}
