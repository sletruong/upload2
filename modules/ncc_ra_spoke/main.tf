# NCC ROUTER-APPLIANCE spoke + the BGP peers that bind it to a TIER-2
# Cloud Router peering surface.
#
# WHY THIS MODULE IS CALLED FROM TIER 5 AND NOT TIER 2:
# `linked_router_appliance_instances` names INSTANCE SELF-LINKS, and instances
# are tier-5 objects. A tier-2 spoke declaring them is a tier-<N reference to a
# tier-N object — FORBIDDEN by design_and_backlog/DESIGN-DOCTRINE.md §4c,
# explicitly INCLUDING via {resolved:}. Destroy runs 5→1, so a tier-2 spoke
# holding tier-5 instance links deadlocks the teardown: the instances would go
# first while the spoke still held them. Here the spoke and the instances live
# in one state and die together.
#
# ⚠ THIS MODULE DOES NOT CREATE ROUTER INTERFACES. They are TIER-2 content,
# declared on the VPC document beside the subnet CIDR they spend from, and
# allocated per design_and_backlog/DESIGN-DOCTRINE.md §5a (BGP peering takes the last two USABLE addresses
# of the subnet). Tier 2 owns the addresses; this module binds to the
# interfaces by name. Creating them here would race tier 2 for the same
# addresses at apply.
#
# TWO LAWS ENCODED HERE (both verified on a live apply):
#   1. The SPOKE must exist BEFORE the peers — `router_appliance_instance` on
#      a peer requires the VM to already be a spoke member.
#   2. A REDUNDANT INTERFACE PAIR is required even for ONE appliance, so every
#      member NIC peers with BOTH interfaces. An HA pair = FOUR sessions.

locals {
  # Per-member × per-interface fan-out. Two members × two interfaces = the
  # four peers that are GCP's documented HA shape, not redundancy for its
  # own sake.
  peer_matrix = var.cloud_router == null ? {} : {
    for pair in setproduct(range(length(var.instances)), [0, 1]) :
    "${var.instances[pair[0]].name}-${pair[1]}" => {
      instance  = var.instances[pair[0]]
      interface = var.cloud_router.interfaces[pair[1]]
    }
  }
}

resource "google_network_connectivity_spoke" "ra" {
  project     = var.project_id
  name        = var.name
  location    = var.region # REGIONAL — unlike a VPC spoke, which is global
  hub         = var.hub
  group       = var.group
  description = var.description
  labels      = var.labels

  linked_router_appliance_instances {
    # ⚠ ONE BLOCK, N `instances` ENTRIES — this is what makes an HA pair share
    # a spoke (no mutual redistribution, equal MED, priority-based failover).
    dynamic "instances" {
      for_each = var.instances
      content {
        virtual_machine = instances.value.self_link
        ip_address      = instances.value.ip_address
      }
    }

    site_to_site_data_transfer = var.site_to_site_data_transfer
    include_import_ranges      = length(var.include_import_ranges) > 0 ? var.include_import_ranges : null
  }
}

# ── BGP peers: one per (member NIC × tier-2 interface) ────────────────────
#
# ⚠ `peer_asn` HERE IS THE APPLIANCE'S OWN ASN. The document calls it
# `local_asn` because from the appliance's point of view it is local — it is
# what the guest announces (`set protocols bgp system-as`). GCP's resource is
# `google_compute_router_peer`, where "peer" means "peer OF THE CLOUD ROUTER",
# so the same number is `peer_asn` at the wire. THIS LINE IS THE TRANSLATION,
# and it happens exactly once so no author holds both perspectives at the
# same time. The Cloud Router's own ASN is declared on the router in tier 2.
#
# ⚠ depends_on IS LOAD-BEARING. The implicit edge runs to the INSTANCE, not
# to the spoke, so without it Terraform is free to create a peer before the
# spoke exists — and the API refuses it.
resource "google_compute_router_peer" "ra" {
  for_each = local.peer_matrix

  project = var.project_id
  region  = var.region
  router  = var.cloud_router.router
  name    = "${var.name}-peer-${each.key}"

  # A TIER-2 interface, by name. Not created here.
  interface = each.value.interface

  peer_ip_address           = each.value.instance.ip_address
  peer_asn                  = each.value.instance.local_asn
  router_appliance_instance = each.value.instance.self_link

  # ⚠ UNSET ON AN HA PAIR BY DESIGN. Equal MED across both members is what
  # yields priority-based failover instead of a route flap between peers.
  advertised_route_priority = try(each.value.instance.advertised_route_priority, null)

  depends_on = [google_network_connectivity_spoke.ra]
}
