output "id" {
  description = "The SPG path — what a tier-0/1/2 firewall rule references via {resolved:} (those tiers may not name tier 5 by name)."
  value       = google_network_security_security_profile_group.this.id
}
output "name" { value = google_network_security_security_profile_group.this.name }
output "profile_id" { value = google_network_security_security_profile.this.id }
