output "id" { value = google_network_security_dns_threat_detector.this.id }
output "name" { value = google_network_security_dns_threat_detector.this.name }
output "excluded_count" {
  description = "VPCs excluded from inspection. Non-zero means part of the project is deliberately unmonitored — worth reading alongside the architectural exclusions in the module header."
  value       = length(var.excluded_networks)
}
