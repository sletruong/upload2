output "id" { value = google_network_services_gateway.this.id }
output "name" { value = google_network_services_gateway.this.name }
output "addresses" {
  description = "The proxy VIP(s). This is the value clients put in their proxy URL — pin `addresses` if that URL is hardcoded anywhere."
  value       = google_network_services_gateway.this.addresses
}
