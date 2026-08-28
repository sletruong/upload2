variable "project_id" {
  description = "The VPC's project."
  type        = string
}

variable "name" {
  description = "PBR name (explicit). Unique per project."
  type        = string
}

variable "network" {
  description = "Network self link (caller-resolved from the enclosing VPC)."
  type        = string
}

variable "description" {
  description = "Free-form description on the PBR resource."
  type        = string
  default     = ""
}

variable "priority" {
  description = "Tie-breaker among matching PBRs (lower wins)."
  type        = number
  default     = null
}

variable "protocol_version" {
  description = "IPV4 | IPV6 — one family per route."
  type        = string

  validation {
    condition     = contains(["IPV4", "IPV6"], var.protocol_version)
    error_message = "protocol_version must be IPV4 or IPV6."
  }
}

variable "protocol" {
  description = "TCP | UDP | ALL (lexicon: provider ip_protocol)."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["TCP", "UDP", "ALL"], var.protocol)
    error_message = "protocol must be TCP, UDP, or ALL."
  }
}

variable "source_range" {
  description = "Match: source CIDR. Null = any source."
  type        = string
  default     = null
}

variable "destination_range" {
  description = "Match: destination CIDR. Null = any destination."
  type        = string
  default     = null
}

variable "next_hop_ilb_address" {
  description = "STEER: IP of a global-access-enabled L4 ILB (value-based — the fabric stage owns PBRs; plan the address, land the NVA behind it later). XOR use_default_routing."
  type        = string
  default     = null

  validation {
    condition     = (var.next_hop_ilb_address != null) != (var.use_default_routing == true)
    error_message = "Exactly one intent: next_hop_ilb_address (steer) XOR use_default_routing: true (exempt)."
  }
}

variable "use_default_routing" {
  description = "EXEMPT: matching traffic follows normal routing (the skip rule)."
  type        = bool
  default     = null
}

variable "network_tags" {
  description = "Scope to VMs with ANY of these network tags (null = all VMs). XOR interconnect_region."
  type        = list(string)
  default     = null

  validation {
    condition     = var.network_tags == null || var.interconnect_region == null
    error_message = "Scope is vm_tags XOR interconnect_region (or neither = all VM traffic)."
  }
}

variable "interconnect_region" {
  description = "Scope to traffic from Interconnect attachments in this region ('all' = every region)."
  type        = string
  default     = null
}
