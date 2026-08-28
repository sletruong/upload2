output "security_profile_group_ids" {
  description = "SPG ids keyed by function token — the reference surface fwp_policy rules consume (action = apply_security_profile_group)."
  value       = { for k, g in google_network_security_security_profile_group.group : k => g.id }
}

output "endpoints" {
  description = "Endpoint ids keyed by <function>:<zone> — stage-1 endpoint associations consume these."
  value       = { for k, e in google_network_security_firewall_endpoint.endpoint : k => e.id }
}

output "summary" {
  description = "Condensed facts for cross-stage tooling."
  value = {
    security_profile_groups = { for k, g in google_network_security_security_profile_group.group : k => { id = g.id } }
    endpoints               = { for k, e in google_network_security_firewall_endpoint.endpoint : k => { id = e.id, zone = e.location } }
  }
}
