output "id" { value = google_network_security_intercept_deployment_group.this.id }
output "name" { value = google_network_security_intercept_deployment_group.this.name }
output "deployment_ids" { value = { for k, d in google_network_security_intercept_deployment.this : k => d.id } }
