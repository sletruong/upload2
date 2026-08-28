output "name" {
  description = "Key name — the handle appliances reference."
  value       = var.name
}

output "public_key" {
  description = <<-EOT
    The PUBLIC half, OpenSSH authorized-keys form, with NO `user:` prefix.

    ⚠ THE PREFIX IS ADDED BY THE APPLIANCE MODULE from that document's
    `vendor` (vyos -> `vyos:`, palo_alto -> `admin:`). It is deliberately
    NOT baked in here: one key serves a mixed fleet, and each box needs its
    own vendor's username.
  EOT
  value = trimspace(
    local.is_create
    ? tls_private_key.this[0].public_key_openssh
    : jsondecode(local.is_sm
      ? data.google_secret_manager_secret_version_access.this[0].secret_data
      : data.local_file.this[0].content
    ).public
  )
}

output "location" {
  description = "WHERE this key lives — surfaced so an operator finds the secret path without reading docs."
  value = {
    mode    = var.mode
    storage = var.storage
    path    = local.resolved_path
    # ⚠ WRITES BOTH HALVES TO DISK. `gcloud compute ssh
    # --ssh-key-file=<p>` reads <p> as the private key AND EXPECTS
    # <p>.pub BESIDE IT — given only a private key it regenerates or
    # errors rather than using what you supplied. The blob carries both
    # halves precisely so this works; emitting only `.private` produced a
    # layout gcloud refuses. chmod 600 or ssh rejects the key as too
    # permissive.
    fetch = var.storage == "secret_manager" ? join(" && ", [
      "gcloud secrets versions access latest --secret=${local.secret_id} --project=${var.project_id} > /tmp/${var.name}.json",
      "jq -r .private /tmp/${var.name}.json > ~/.ssh/${var.name}",
      "jq -r .public /tmp/${var.name}.json > ~/.ssh/${var.name}.pub",
      "chmod 600 ~/.ssh/${var.name}",
      "rm -f /tmp/${var.name}.json",
      ]) : join(" && ", [
      "jq -r .private ${local.local_path} > ~/.ssh/${var.name}",
      "jq -r .public ${local.local_path} > ~/.ssh/${var.name}.pub",
      "chmod 600 ~/.ssh/${var.name}",
    ])

    # Hand this to `gcloud compute ssh --ssh-key-file=`.
    ssh_key_file = "~/.ssh/${var.name}"
  }
}
