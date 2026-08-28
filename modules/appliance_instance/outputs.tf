output "self_link" {
  description = "Instance self link (IG membership plumbing)."
  value       = google_compute_instance.this.self_link
}

output "addresses" {
  description = "Per-NIC primary internal addresses, in NIC order — the guest-config contract (a/b-style pins verified against actuals)."
  value       = [for nic in google_compute_instance.this.network_interface : nic.network_ip]
}

output "external_addresses" {
  description = "Per-NIC external addresses (null where unexposed) — asymmetric exposure surfaces here."
  value       = [for nic in google_compute_instance.this.network_interface : try(nic.access_config[0].nat_ip, null)]
}
