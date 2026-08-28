# NAMED SSH KEY — declared once in tier 1, referenced by many appliances.
#
# WHY A NAMED FAMILY AT ALL: a key pasted inline into each appliance
# document has to be re-pasted on every rotation, and the prefix retyped
# each time. Here rotation touches ONE declaration.
#
# ⚠ THE SECRET HOLDS BOTH HALVES AS ONE JSON BLOB:
#     {"private": "-----BEGIN...", "public": "ssh-rsa AAAA..."}
# One secret, one fetch, and the PUBLIC half is directly readable for a
# `reference` key. The alternative — storing only the private half and
# deriving the public one at plan time — pulls a key the framework does not
# own through Terraform state to compute something the operator already has.
#
# ⚠ STATE: `tls_private_key` transits Terraform state in BOTH storage modes.
# `secret_manager` improves DISTRIBUTION (who can fetch it), NOT state
# hygiene. Do not let the enum imply otherwise.

locals {
  is_create = var.mode == "create"
  is_sm     = var.storage == "secret_manager"

  secret_id     = coalesce(try(regex("[^/]+$", var.path), null), var.name)
  local_path    = coalesce(var.path, "${coalesce(var.local_dir, path.root)}/.keys/${var.name}.json")
  resolved_path = local.is_sm ? "projects/${var.project_id}/secrets/${local.secret_id}" : local.local_path
}

# ── mode = create ─────────────────────────────────────────────────────────
resource "tls_private_key" "this" {
  count = local.is_create ? 1 : 0

  algorithm = var.algorithm
  rsa_bits  = var.algorithm == "RSA" ? var.rsa_bits : null
}

resource "google_secret_manager_secret" "this" {
  count = local.is_create && local.is_sm ? 1 : 0

  project   = var.project_id
  secret_id = local.secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "this" {
  count = local.is_create && local.is_sm ? 1 : 0

  secret = google_secret_manager_secret.this[0].id
  # BOTH halves, one blob. `public` is the OpenSSH authorized-keys form and
  # is what the appliance module prefixes with the vendor's admin user.
  secret_data = jsonencode({
    private = tls_private_key.this[0].private_key_openssh
    public  = trimspace(tls_private_key.this[0].public_key_openssh)
  })
}

# ⚠ WRITES A PLAINTEXT PRIVATE KEY TO DISK. Lab-only by construction — the
# schema's `storage` description says so, and `local` means exactly one
# operator can reach any box keyed with it. Because day-0 metadata is
# first-boot only, that is a PERMANENT property of the instance.
resource "local_sensitive_file" "this" {
  count = local.is_create && !local.is_sm ? 1 : 0

  filename        = local.local_path
  file_permission = "0600"
  content = jsonencode({
    private = tls_private_key.this[0].private_key_openssh
    public  = trimspace(tls_private_key.this[0].public_key_openssh)
  })
}

# ── mode = reference ──────────────────────────────────────────────────────
# READ ONLY. No secret resource is declared, so destroy cannot delete a key
# this framework did not create.
data "google_secret_manager_secret_version_access" "this" {
  count = !local.is_create && local.is_sm ? 1 : 0

  project = var.project_id
  secret  = local.secret_id
}

data "local_file" "this" {
  count = !local.is_create && !local.is_sm ? 1 : 0

  filename = local.local_path
}
