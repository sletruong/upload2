# Policy-based route (fabric): steer matching traffic to an L4 ILB ADDRESS
# regardless of the routing table, or exempt it (use_default_routing). The
# next hop is a VALUE (an IP), so the fabric stage owns PBRs — the
# insertion pattern plans the ILB address here and lands the stage-4 NVA
# behind it later. Lexicon: provider next_hop_other_routes="DEFAULT_ROUTING"
# is surfaced as the boolean intent use_default_routing.

resource "google_network_connectivity_policy_based_route" "pbr" {
  project = var.project_id
  name    = var.name
  # networkconnectivity rejects FULL compute URLs — it demands the partial
  # projects/P/global/networks/N form (verified live)
  network     = trimprefix(var.network, "https://www.googleapis.com/compute/v1/")
  description = var.description
  priority    = var.priority

  filter {
    protocol_version = var.protocol_version
    ip_protocol      = var.protocol
    src_range        = var.source_range
    dest_range       = var.destination_range
  }

  next_hop_ilb_ip       = var.next_hop_ilb_address
  next_hop_other_routes = var.use_default_routing == true ? "DEFAULT_ROUTING" : null

  dynamic "virtual_machine" {
    for_each = var.network_tags != null ? [1] : []
    content {
      tags = var.network_tags
    }
  }

  dynamic "interconnect_attachment" {
    for_each = var.interconnect_region != null ? [1] : []
    content {
      region = var.interconnect_region
    }
  }
}
