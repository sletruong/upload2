output "ids" {
  description = "Address group resource paths keyed by state identity — the reference surface policy rules consume."
  value       = { for k, g in google_network_security_address_group.group : k => g.id }
}
