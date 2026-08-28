output "id" {
  description = "Endpoint group path — what an SPG document references via endpoint_group."
  value       = local.is_mirror ? google_network_security_mirroring_endpoint_group.this[0].id : google_network_security_intercept_endpoint_group.this[0].id
}
output "name" {
  value = local.is_mirror ? google_network_security_mirroring_endpoint_group.this[0].name : google_network_security_intercept_endpoint_group.this[0].name
}
output "association_ids" {
  value = local.is_mirror ? { for k, a in google_network_security_mirroring_endpoint_group_association.this : k => a.id } : { for k, a in google_network_security_intercept_endpoint_group_association.this : k => a.id }
}
