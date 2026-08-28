variable "project_id" {
  description = "Project owning the secret."
  type        = string
}

variable "name" {
  description = "Key name (explicit — the handle appliances reference)."
  type        = string
}

variable "mode" {
  description = <<-EOT
    ⚠ REQUIRED, NEVER DEFAULTED — the two modes have OPPOSITE destroy
    semantics.

    `create`    — this module generates the keypair and OWNS the secret.
                  Destroy DELETES it.
    `reference` — the key already exists (typically a platform team's, on
                  its own rotation schedule). This module READS it and never
                  writes or deletes it.

    A module that assumes it owns every secret will DELETE one on destroy
    that it did not create. That is why there is no default.
  EOT
  type        = string

  validation {
    condition     = contains(["create", "reference"], var.mode)
    error_message = "mode must be create or reference."
  }
}

variable "storage" {
  description = <<-EOT
    ⚠ AN OPERATOR-ACCESS CHOICE, NOT A SECURITY SPECTRUM. Read it as "is
    this key shared with other humans?"

    `secret_manager` — the team can fetch it; IAM decides who.
    `local`          — a file beside the stage root. THROWAWAY LAB ONLY.

    ⚠ NEITHER KEEPS THE PRIVATE KEY OUT OF TERRAFORM STATE. `tls_private_key`
    transits state regardless. Secret Manager improves DISTRIBUTION, not
    state hygiene.
  EOT
  type        = string

  validation {
    condition     = contains(["secret_manager", "local"], var.storage)
    error_message = "storage must be secret_manager or local."
  }
}

variable "path" {
  description = "Secret resource path or local file path. REQUIRED for mode=reference (schema-enforced); for mode=create, null means derive from name."
  type        = string
  default     = null
}

variable "algorithm" {
  description = "Key algorithm for mode=create. ⚠ VERIFY VENDOR SUPPORT BEFORE ED25519 — some appliance images accept RSA only. RSA is what the references/arch-nsi-intercept fleet used."
  type        = string
  default     = "RSA"
}

variable "rsa_bits" {
  description = "RSA key size for mode=create."
  type        = number
  default     = 4096
}

variable "local_dir" {
  description = "Directory for storage=local files (caller passes its own path.module so the file lands beside the stage root)."
  type        = string
  default     = null
}
