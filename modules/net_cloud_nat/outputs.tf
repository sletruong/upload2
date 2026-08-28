output "static_ips" {
  description = "Addresses created for this NAT: name => external IP (the egress allow-list surface)."
  value       = { for k, a in google_compute_address.static : k => a.address }
}

output "id" {
  description = "NAT id (projects/*/regions/*/routers/*/nats/*-style provider id)."
  value       = google_compute_router_nat.nat.id
}
