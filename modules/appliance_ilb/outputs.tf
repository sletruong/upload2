output "address" {
  description = "The claimed VIP value (from the reservation — plan-known, stable). depends_on the forwarding rule IS the steering graph edge: join-form routes consuming this output create after the rule and destroy before it (the order-of-operations law, by construction)."
  value       = data.google_compute_address.vip.address

  depends_on = [google_compute_forwarding_rule.this]
}

output "forwarding_rule" {
  description = "Forwarding rule self link."
  value       = google_compute_forwarding_rule.this.self_link
}

output "backend_count" {
  description = "Covering partition IGs — 0 = frontend live but blackholing (the staged/forgotten warning fires in the stack)."
  value       = length(var.backends)
}
