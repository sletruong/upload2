output "summary" {
  description = "What this binding manages: mode, policy handle, created policy id (create mode), attached rule priorities."
  value = {
    mode      = var.mode
    policy    = var.policy
    policy_id = var.mode == "create" ? (var.type == "global" ? google_compute_network_firewall_policy.created[0].id : google_compute_region_network_firewall_policy.created[0].id) : null
    rules     = sort(keys(var.rules))
  }
}
