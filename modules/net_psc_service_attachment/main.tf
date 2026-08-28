# PSC service attachment — the PRODUCER half. Publishes a service so
# consumers in other VPCs/projects can create an endpoint to it.
#
# ⚠ REGION IS THE BINDING CONSTRAINT: the NAT subnet, this attachment, and
# EVERY consumer endpoint must share one region. There is no cross-region
# PSC endpoint.
resource "google_compute_service_attachment" "this" {
  project     = var.project_id
  name        = var.name
  region      = var.region
  description = var.description

  target_service        = var.target_service
  nat_subnets           = var.nat_subnets
  connection_preference = var.connection_preference
  enable_proxy_protocol = var.enable_proxy_protocol
}
