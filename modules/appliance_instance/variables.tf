variable "project_id" {
  description = "Project hosting the instance (state identity: <project>/<zone>/<name>)."
  type        = string
}

variable "name" {
  description = "Instance name (explicit — the document identity)."
  type        = string
}

variable "zone" {
  description = "Zone; NIC subnetworks resolve in this zone's region."
  type        = string
}

variable "machine_type" {
  description = "Machine shape — also the interface budget (physical + dynamic share one pool ≈ vCPU count)."
  type        = string
}

variable "min_cpu_platform" {
  description = "Minimum CPU platform override (e.g. \"AMD Milan or later\"). null = GCP picks within the machine family."
  type        = string
  default     = null
}

variable "image" {
  description = "Boot image path (projects/<p>/global/images/<name>) — {resolved:}-only at the document layer."
  type        = string
}

variable "network_tags" {
  description = "Network tags (HC-allow + steering targets; the fabric pre-pays the HC-allow rule)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "metadata" {
  description = "Instance metadata passed through UNINTERPRETED. Vendor day-0 lives here: PAN-OS reads init-cfg keys (type, plugin-op-commands, ...) directly from metadata, and cloud-init images read user-data. The framework does NOT validate keys — a typo is accepted by GCE and ignored by the guest."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "spot" {
  description = "SPOT provisioning — preemptible capacity at a steep discount, RECLAIMABLE BY GCP AT ANY TIME with 30s notice. Lab/reference use only: an appliance is a forwarding path, so a preemption is a DATA-PLANE OUTAGE, not a degraded node."
  type        = bool
  default     = false
  nullable    = false
}

variable "nics" {
  description = "Ordered physical NICs — position IS the GCP index, fixed at creation. Every NIC must land in a UNIQUE VPC network (GA law — GCP rejects violations at apply)."
  type = list(object({
    # ⚠ NULLABLE. A PSC-interface NIC has NO subnetwork — its address comes
    # from a subnet in ANOTHER project, chosen by the attachment.
    subnetwork      = optional(string)
    private_address = optional(string)
    external        = optional(bool, false)

    # ⚠ MUST BE DECLARED HERE OR TERRAFORM SILENTLY STRIPS IT. Object
    # coercion drops undeclared attributes with no warning, so the NIC would
    # render as an ordinary interface with no subnet and no attachment.
    network_attachment = optional(string)
  }))

  validation {
    condition     = length(var.nics) >= 1
    error_message = "An appliance needs at least one NIC."
  }

  # ⚠ THE PROVIDER WILL NOT CATCH THIS — MEASURED. A NIC declaring both
  # `subnetwork` and `network_attachment` validates and plans without
  # complaint, and the provider resolves the contradiction silently.
  validation {
    condition = alltrue([
      for n in var.nics :
      !(try(n.subnetwork, null) != null && try(n.network_attachment, null) != null)
    ])
    error_message = "A NIC cannot have both subnetwork and network_attachment — an address comes from ONE subnet. The provider accepts both and picks silently."
  }

  # ⚠ nic0 CANNOT BE THE PSC INTERFACE (GCP law). "The first network
  # interface is the default network interface, named nic0. This interface
  # connects to a producer subnet."
  validation {
    condition     = length(var.nics) == 0 || try(var.nics[0].network_attachment, null) == null
    error_message = "nic0 cannot be a PSC interface — it must be an ordinary NIC in this project's own subnet. A PSC interface is nic1 or later."
  }
}

variable "service_account_email" {
  description = "Service-account email to attach (cloud-platform scope; IAM governs access). null = NO service account. ⚠ REQUIRED FOR FORTIGATE — the vendor's boot-time GCP instance-identity check needs the metadata identity endpoint, which only exists with an attached SA; without one the box logs 'GCP instance check failed' and SELF-TERMINATES ~2 minutes after boot (measured live 2026-08-13, serial-confirmed). The check is metadata-local: the SA needs no roles."
  type        = string
  default     = null
}
