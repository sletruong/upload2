# Network firewall policy -> VPC association (fabric): the act that makes a
# tier-0 (or fabric-created) policy ENFORCE on a network. Policies are born
# unassociated by design — association shares the VPC lifecycle, so it lives
# here: created after the VPC, destroyed before it.

resource "google_compute_network_firewall_policy_association" "global" {
  count = var.type == "global" ? 1 : 0

  project           = var.project_id
  name              = var.name
  firewall_policy   = var.policy
  attachment_target = var.network
}

resource "google_compute_region_network_firewall_policy_association" "regional" {
  count = var.type == "regional" ? 1 : 0

  project           = var.project_id
  region            = var.region
  name              = var.name
  firewall_policy   = var.policy
  attachment_target = var.network
}
