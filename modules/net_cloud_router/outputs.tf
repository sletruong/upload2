output "id" {
  description = "Router id (projects/*/regions/*/routers/*)."
  value       = var.pre_existing ? "projects/${var.project_id}/regions/${var.region}/routers/${var.name}" : google_compute_router.router[0].id
}

output "name" {
  description = "Router name — the reference surface for NATs, BGP peers, and stage-2 hybrid attachments."
  value       = var.name
}

output "interfaces" {
  description = "Interface names — the surface BGP peers (fabric-future) and NCC appliance spokes (stage 5) bind to."
  value = concat(
    [for k, i in google_compute_router_interface.primary : k],
    [for k, i in google_compute_router_interface.redundant : k]
  )
}

output "route_policies" {
  description = "Policy library: name => type — the subscription surface for BGP sessions."
  value       = { for k, p in google_compute_router_route_policy.policy : k => trimprefix(p.type, "ROUTE_POLICY_TYPE_") }
}
