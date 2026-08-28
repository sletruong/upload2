output "instance" {
  value = google_compute_instance.this
}

output "self_link" {
  value = google_compute_instance.this.self_link
}