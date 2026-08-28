output "id" {
  description = "Attachment id — projects/<project>/regions/<region>/networkAttachments/<name>. ⚠ A project ID here is SAFE: the provider normalizes, verified across apply and re-plan with no perma-diff."
  value       = google_compute_network_attachment.this.id
}

output "self_link" {
  description = "Attachment self link — what a producer's NIC references."
  value       = google_compute_network_attachment.this.self_link
}

output "connected_endpoints" {
  description = <<-EOT
    Accepted producer interfaces: their address, project and status.

    ⚠ `status: ACCEPTED` MEANS THE CONTROL PLANE JOINED — NOTHING MORE.
    Measured: with an endpoint ACCEPTED and an address allocated, the guest
    interface was DOWN with no address and the dataplane showed 100% loss.
    GCP does not bring the interface up; the producer must configure it.
  EOT
  value       = google_compute_network_attachment.this.connection_endpoints
}
