output "gateway_interfaces" {
  description = "The GCP-side public IPs per gateway interface — what the on-prem side configures as ITS peers."
  value       = { for i in google_compute_ha_vpn_gateway.gateway.vpn_interfaces : i.id => i.ip_address }
}

output "generated_secrets" {
  description = "Generated PSKs by tunnel name — hand to the far side over a real secret channel."
  value       = { for tn, p in random_password.psk : tn => p.result }
  sensitive   = true
}

output "tunnels" {
  description = "Tunnel name => detailed status (watch 'Tunnel is up and running')."
  value       = { for tn, t in google_compute_vpn_tunnel.tunnel : tn => t.detailed_status }
}

output "spoke_state" {
  description = "NCC hybrid spoke state (null when no spoke declared)."
  value       = try(google_network_connectivity_spoke.spoke[0].state, null)
}

output "gcp_solo_generated_secrets" {
  description = "One-side generated PSKs by tunnel — hand to the far side."
  value       = { for tn, p in random_password.gcp_solo_psk : tn => p.result }
  sensitive   = true
}
