output "intercept_deployment_group_id" {
  value       = google_network_security_intercept_deployment_group.this.id
  description = "ID of the NSI intercept deployment group"
}

output "intercept_endpoint_group_id" {
  value       = google_network_security_intercept_endpoint_group.this.id
  description = "ID of the NSI intercept endpoint group"
}

output "security_profile_id" {
  value       = google_network_security_security_profile.this.id
  description = "ID of the custom intercept security profile"
}

output "security_profile_group_id" {
  value       = google_network_security_security_profile_group.this.id
  description = "ID of the security profile group (referenced by firewall policy rules)"
}

output "firewall_policy_id" {
  value       = google_compute_network_firewall_policy.this.id
  description = "ID of the network firewall policy"
}

output "ilb_ip_addresses" {
  value       = { for k, v in google_compute_forwarding_rule.palo : k => v.ip_address }
  description = "Map of zone-key => ILB IP address fronting the Palo Alto backends"
}
