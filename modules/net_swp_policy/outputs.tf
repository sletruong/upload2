output "id" { value = google_network_security_gateway_security_policy.this.id }
output "name" { value = google_network_security_gateway_security_policy.this.name }
output "rule_count" { value = length(var.rules) }
