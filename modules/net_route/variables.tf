variable "project_id" {
  description = "The VPC's project."
  type        = string
}

variable "name" {
  description = "Route name (explicit — the naming layer's contract). Unique per project."
  type        = string
}

variable "network" {
  description = "Network self link (caller-resolved — the ordering edge)."
  type        = string
}

variable "description" {
  description = "Route description."
  type        = string
  default     = ""
}

variable "destination" {
  description = "Destination range."
  type        = string

  validation {
    # cidrnetmask is v4-only; cidrhost parses both families (v6 parity
    # verified live)
    condition     = can(cidrhost(var.destination, 0))
    error_message = "destination must be a valid IPv4 or IPv6 CIDR."
  }
}

variable "next_hop_internet" {
  description = "Route via the default internet gateway. Exactly one of next_hop_internet / next_hop_address / next_hop_ilb_address (route ownership follows the next hop; tunnel-bound statics live on the owning hybrid connection, stage 4)."
  type        = bool
  default     = false

  validation {
    condition     = length([for on in [var.next_hop_internet, var.next_hop_address != null, var.next_hop_ilb_address != null] : on if on]) == 1
    error_message = "Exactly ONE next hop: next_hop_internet XOR next_hop_address XOR next_hop_ilb_address (tunnel/instance next hops are NOT this module's content — stage 4 owns those)."
  }
}

variable "next_hop_address" {
  description = "Route via an internal IP (must sit inside one of the network's subnet ranges)."
  type        = string
  default     = null

  validation {
    # The API rejects a family mix (400, verified live): "destination range
    # and next hop ip address must use the same IP version"
    condition     = var.next_hop_address == null ? true : (can(regex(":", var.destination)) == can(regex(":", var.next_hop_address)))
    error_message = "Route destination and next_hop_address must be the same IP family (GCP rejects the mix with a 400)."
  }
}

variable "priority" {
  description = "Route priority (lower wins)."
  type        = number
  default     = 1000
}

variable "network_tags" {
  description = "Instance tags this route applies to (empty = all instances)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "next_hop_ilb_address" {
  description = "Internal passthrough NLB VIP (IPv4 value). VALUE callers hold a published VIP they don't own (split-ownership; creation legal only after the rule exists — GCP errors otherwise). JOIN callers (5-appliance/routes/) pass the same-state resolved VIP, sequenced by the frontend output's depends_on."
  type        = string
  default     = null
}
