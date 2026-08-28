# Firewall endpoint -> VPC association (fabric): the enforcement act that
# makes a tier-0 zonal endpoint inspect THIS network's traffic. Endpoints are
# created wherever the container hierarchy demands (org- or project-parented,
# tier 0); the association shares the VPC lifecycle, so it lives here.
# Reminder from the endpoint's config.jumbo_frames intent: the inspected
# path's MTU must match what the endpoint declared.

resource "google_network_security_firewall_endpoint_association" "association" {
  name     = var.name
  parent   = "projects/${var.project_id}"
  location = var.zone

  firewall_endpoint     = var.endpoint
  network               = var.network
  tls_inspection_policy = var.tls_inspection_policy
  disabled              = !var.enabled # lexicon owns the polarity flip
}
