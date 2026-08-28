# Static route: VALUE-BASED next hops — internet gateway, internal IP, or a
# published ILB VIP (the steering razor: value form = the caller does
# NOT own the fleet; join-form steering is 5-appliance/routes/ and reaches
# this module with the VIP already resolved + graph-sequenced). Tunnel
# statics still belong to their connection (stage 4). Exposing every
# next-hop type raw invites routes that cannot be destroyed cleanly; the
# razor — route ownership follows the next hop — is deliberate, not field
# scarcity.

resource "google_compute_route" "route" {
  project     = var.project_id
  network     = var.network
  name        = var.name
  description = var.description

  dest_range = var.destination
  priority   = var.priority
  tags       = var.network_tags

  next_hop_gateway = var.next_hop_internet ? "default-internet-gateway" : null
  next_hop_ip      = var.next_hop_address
  # ORDER-OF-OPERATIONS LAW (Google's internal passthrough LB next-hop
  # documentation): the forwarding rule
  # must exist first, and cannot be deleted while this route lives — join
  # callers get both by the graph; value callers by calendar (fail-loud).
  next_hop_ilb = var.next_hop_ilb_address
}
