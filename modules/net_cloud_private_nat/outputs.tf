output "id" {
  description = "Private NAT id."
  value       = google_compute_router_nat.nat.id
}
