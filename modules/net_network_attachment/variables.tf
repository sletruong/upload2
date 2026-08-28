variable "project_id" {
  description = "Project owning the attachment — the CONSUMER side, i.e. the side being reached."
  type        = string
}

variable "name" {
  description = "Attachment name (explicit). The handle a producer's NIC names; publish it WITH the region."
  type        = string
}

variable "region" {
  description = "Region — supplied by the parent subnet, never restated in the document. Force-new, and there is no cross-region form: the producer's nic0 subnet must match."
  type        = string
}

variable "subnetwork" {
  description = "Self link of the subnet that supplies addresses to accepted interfaces — supplied by the nesting."
  type        = string
}

variable "connection_preference" {
  description = <<-EOT
    ACCEPT_MANUAL or ACCEPT_AUTOMATIC.

    ⚠ ACCEPT_AUTOMATIC means ANY project that can name this attachment's URI
    may put a NIC into this VPC and take an address from its subnet. There is
    no second gate behind it.

    ⚠ FORCE-NEW, and the recreate is blocked while any connection is open.
  EOT
  type        = string

  validation {
    condition     = contains(["ACCEPT_MANUAL", "ACCEPT_AUTOMATIC"], var.connection_preference)
    error_message = "connection_preference must be ACCEPT_MANUAL or ACCEPT_AUTOMATIC (the API's INVALID is an enum artifact, not a choice)."
  }
}

variable "producer_accept_lists" {
  description = "PROJECT IDs or NUMBERS allowed to attach — the side that owns the VM. ⚠ An unlisted producer does not get a degraded NIC: their VM CREATION FAILS, in their state."
  type        = list(string)
  default     = []
}

variable "producer_reject_lists" {
  description = "Projects explicitly denied. ⚠ REJECT WINS — a project in both lists is rejected, which reads like an approval."
  type        = list(string)
  default     = []
}

variable "description" {
  description = "Attachment description."
  type        = string
  default     = ""
}
