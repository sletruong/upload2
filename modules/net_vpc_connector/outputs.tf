output "id" {
  description = "Connector id — what Cloud Run/Functions vpc_access annotations reference."
  value       = google_vpc_access_connector.connector.id
}

output "state" {
  description = "Connector state."
  value       = google_vpc_access_connector.connector.state
}
