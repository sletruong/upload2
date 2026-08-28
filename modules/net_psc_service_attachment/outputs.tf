output "id" { value = google_compute_service_attachment.this.id }
output "self_link" {
  description = "The path consumers put in their forwarding rule's target: projects/<p>/regions/<r>/serviceAttachments/<n>."
  value       = google_compute_service_attachment.this.self_link
}
