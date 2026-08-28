# PSC INTERFACE ATTACHMENT — this VPC accepts network interfaces from VMs in
# another project, and hands each one an address from `subnetwork`.
#
# ⚠ THE VOCABULARY IS INVERTED. GCP calls the side that owns the VM the
# PRODUCER and the side being reached the CONSUMER. This module builds the
# CONSUMER side; `producer_accept_lists` names the side with the VM.
#
# ⚠ TIER 2 OWNS THIS, AND THE LADDER IS NOT INVERTED. The accept list holds
# PROJECT IDs — container identifiers from outside the estate — not resource
# references. No name-map lookup, no Terraform edge, no destroy-order
# coupling to any tier-5 or tier-9 object. Verified live: create runs 2→5,
# destroy 5→2, and the attachment deleted cleanly once the VM was gone.
#
# ⚠ TEARDOWN IS COORDINATED ACROSS AN ESTATE BOUNDARY. An attachment with
# open connections cannot be deleted — the producer must delete their VM
# first. Within one estate the ladder handles it; across two orgs their VM
# blocks this destroy and nothing in this plan shows it.

resource "google_compute_network_attachment" "this" {
  project = var.project_id
  name    = var.name
  region  = var.region

  description = var.description

  # ⚠ SINGULAR IN THE DOCUMENT, LIST AT THE API. "A network attachment is
  # associated with a SINGLE subnet" — the document states the law and this
  # module wraps it, so a second entry is unrepresentable upstream.
  subnetworks = [var.subnetwork]

  # ⚠ THE SECURITY FIELD, AND FORCE-NEW. Not updatable, so tightening
  # AUTOMATIC→MANUAL destroys and recreates — which GCP refuses while any
  # connection is open. The window to fix a permissive attachment closes the
  # moment someone uses it.
  connection_preference = var.connection_preference

  producer_accept_lists = length(var.producer_accept_lists) > 0 ? var.producer_accept_lists : null
  producer_reject_lists = length(var.producer_reject_lists) > 0 ? var.producer_reject_lists : null
}
