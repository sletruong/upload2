# PSC endpoint — the CONSUMER half. A forwarding rule in the consumer's own
# VPC that targets a producer's service attachment.
#
# WHAT THIS BUYS: the consumer reaches the service by a PRIVATE address in
# its OWN VPC. No peering, no shared VPC, no route between the two networks,
# and no transitivity problem — which is why PSC is the answer for a
# centralized egress proxy across many VPCs and projects.
#
# ⚠ ONE ENDPOINT PER VPC PER REGION that needs the service. This is not a
# global object; each consuming VPC creates its own.
#
# ⚠ THE ADDRESS IS THE CONTRACT for Secure Web Proxy: workloads set it in
# HTTP_PROXY / HTTPS_PROXY. Reserve it (ip_address) rather than letting it
# float.
resource "google_compute_address" "endpoint" {
  count = var.ip_address == null ? 0 : 1

  project      = var.project_id
  name         = "${var.name}-addr"
  region       = var.region
  subnetwork   = var.subnetwork
  address_type = "INTERNAL"
  address      = var.ip_address
}

resource "google_compute_forwarding_rule" "this" {
  project = var.project_id
  name    = var.name
  region  = var.region

  network               = var.network
  subnetwork            = var.subnetwork
  ip_address            = var.ip_address == null ? null : google_compute_address.endpoint[0].self_link
  target                = var.target
  load_balancing_scheme = "" # REQUIRED to be empty for a PSC endpoint
}
