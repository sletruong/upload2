# ═══════════════════════════════════════════════════════════════════════════════
# SSH KEY UPLOAD — existing key pairs → Secret Manager
# ───────────────────────────────────────────────────────────────────────────────
# Reads the pre-existing key files from the ADT-Lab directory and stores them
# in Secret Manager in the JSON blob format the ssh_key module expects:
#   {"private": "-----BEGIN...", "public": "ssh-... <comment>"}
#
# The framework's module/ssh_key reads the `.public` field and injects it into
# instance metadata with the vendor-specific `admin:` prefix.
#
# APPLY SEQUENCE (first time only, before secrets exist):
#   terraform apply \
#     -target=google_secret_manager_secret_version.cisco_ssh_key \
#     -target=google_secret_manager_secret_version.palo_ssh_key
#   terraform apply
#
# On all subsequent applies the secrets persist in Secret Manager; the local
# key files are still read at plan time (data sources below), so they must
# remain at the paths below. The private key is never written to Terraform
# state — it is only stored in Secret Manager.
# ═══════════════════════════════════════════════════════════════════════════════

locals {
  cisco_key_dir = abspath("${path.module}/../../../Example Clients/ADT-Lab")
}

# ─── Read local key files ─────────────────────────────────────────────────────

data "local_sensitive_file" "cisco_private" {
  filename = "${local.cisco_key_dir}/.ssh-cisco"
}

data "local_file" "cisco_public" {
  filename = "${local.cisco_key_dir}/.ssh-cisco.pub"
}

data "local_sensitive_file" "palo_private" {
  filename = "${local.cisco_key_dir}/.ssh-palo"
}

data "local_file" "palo_public" {
  filename = "${local.cisco_key_dir}/.ssh-palo.pub"
}

# ─── Secret Manager secrets ───────────────────────────────────────────────────

resource "google_secret_manager_secret" "cisco_ssh_key" {
  project   = local.config.project.project_id
  secret_id = "adt-lab-cisco-ssh-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "palo_ssh_key" {
  project   = local.config.project.project_id
  secret_id = "adt-lab-palo-ssh-key"
  replication {
    auto {}
  }
}

# ─── Secret versions ──────────────────────────────────────────────────────────
# ignore_changes on secret_data: key rotation is an explicit act (update the
# file, remove ignore_changes, apply), not an automatic diff on every plan.

resource "google_secret_manager_secret_version" "cisco_ssh_key" {
  secret = google_secret_manager_secret.cisco_ssh_key.id
  secret_data = jsonencode({
    private = data.local_sensitive_file.cisco_private.content
    public  = trimspace(data.local_file.cisco_public.content)
  })
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "palo_ssh_key" {
  secret = google_secret_manager_secret.palo_ssh_key.id
  secret_data = jsonencode({
    private = data.local_sensitive_file.palo_private.content
    public  = trimspace(data.local_file.palo_public.content)
  })
  lifecycle {
    ignore_changes = [secret_data]
  }
}
