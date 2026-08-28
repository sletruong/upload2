/**
 * net_address — the standalone `addresses` family. Three forms:
 *   - regional EXTERNAL (classic reserved egress/frontend IP — value GCP-
 *     assigned, read back in outputs).
 *   - regional INTERNAL — subnet-bound, optionally pinned. The PBR-steering
 *     pattern done properly: reserve the ILB address the stage-4 NVA claims.
 *   - global EXTERNAL (future global LB frontend).
 * Global INTERNAL ranges are private_services_access territory, not here.
 */

resource "google_compute_address" "regional" {
  count = var.scope == "global" ? 0 : 1

  project      = var.project_id
  name         = var.name
  region       = var.scope
  description  = var.description
  address_type = var.type
  subnetwork   = var.subnetwork
  address      = var.address
  # provider defaults purpose to GCE_ENDPOINT for INTERNAL; only pass an opinion
  purpose = var.type == "INTERNAL" ? var.purpose : null
}

resource "google_compute_global_address" "global" {
  count = var.scope == "global" ? 1 : 0

  project      = var.project_id
  name         = var.name
  description  = var.description
  address_type = "EXTERNAL"
  ip_version   = var.ip_version
}
