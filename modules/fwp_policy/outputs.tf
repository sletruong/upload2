output "id" {
  description = "Policy id (whichever flavor was created)."
  value = one(concat(
    google_compute_firewall_policy.hierarchical[*].id,
    google_compute_network_firewall_policy.global[*].id,
    google_compute_region_network_firewall_policy.regional[*].id
  ))
}

output "name" {
  description = "Policy name."
  value       = var.name
}

output "summary" {
  description = "Condensed facts for cross-stage tooling (stage-1 VPC associations consume the name for network types)."
  value = {
    id = one(concat(
      google_compute_firewall_policy.hierarchical[*].id,
      google_compute_network_firewall_policy.global[*].id,
      google_compute_region_network_firewall_policy.regional[*].id
    ))
    name       = var.name
    type       = var.type
    scope      = var.type == "regional" ? var.region : (var.type == "global" ? "global" : local.parent)
    rule_count = length(var.rules)
  }
}
