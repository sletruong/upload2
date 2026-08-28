output "id" {
  description = "Spoke id."
  value       = google_network_connectivity_spoke.ra.id
}

output "name" {
  description = "Spoke name."
  value       = google_network_connectivity_spoke.ra.name
}

output "state" {
  description = "Spoke state. ⚠ ACTIVE IS NOT A DATAPLANE — it says the control plane accepted the spoke, nothing about whether a packet survives."
  value       = google_network_connectivity_spoke.ra.state
}

output "peer_names" {
  description = "BGP peer names actually created — empty when the spoke was built WITHOUT a cloud_router binding (spoke-only staging: the operator brings adjacency up by hand over IAP). An HA pair on a bound spoke yields FOUR."
  value       = sort([for k, p in google_compute_router_peer.ra : p.name])
}
