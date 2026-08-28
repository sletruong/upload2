variable "project_id" {
  description = "Project hosting the frontend (state identity: <project>/<region>/<name>)."
  type        = string
}

variable "name" {
  description = "Frontend name — shared by the forwarding rule, backend service and health check (separate namespaces, 1:1 plumbing)."
  type        = string
}

variable "region" {
  description = "Frontend region."
  type        = string
}

variable "network" {
  description = "Frontend VPC self link — ALSO the backend delivery selector: GCP delivers to each member's NIC in THIS network (nic0 when it matches the IG network, the matching non-nic0 NIC otherwise — see Google's internal passthrough Network Load Balancer documentation on backends and network interfaces)."
  type        = string
}

variable "subnetwork" {
  description = "Frontend subnetwork path (frontend home — declared, not derived)."
  type        = string
}

variable "address" {
  description = "Fabric VIP reservation name (from the address family) — claimed via data source, purpose SHARED_LOADBALANCER_VIP enforced at plan."
  type        = string
}

variable "protocol" {
  description = "L3_DEFAULT (all-protocol next-hop duty) | TCP | UDP."
  type        = string

  validation {
    condition     = contains(["L3_DEFAULT", "TCP", "UDP"], var.protocol)
    error_message = "protocol must be L3_DEFAULT, TCP or UDP."
  }
}

variable "ports" {
  description = "Frontend ports (TCP/UDP only; empty = all ports). Structurally unwritable under L3_DEFAULT."
  type        = list(number)
  default     = []
  nullable    = false

  validation {
    condition     = length(var.ports) == 0 || var.protocol != "L3_DEFAULT"
    error_message = "ports are unwritable under L3_DEFAULT (schema enforces this upstream; the module holds the same line)."
  }
}

variable "global_access" {
  description = "Allow cross-region clients — required for cross-region steering (regionalized pattern, PBR next-hops)."
  type        = bool
  default     = true
}

variable "session_affinity" {
  description = "Backend affinity (CLIENT_IP_PROTO = the stateful-NVA default)."
  type        = string
  default     = "CLIENT_IP_PROTO"
}

variable "health_check" {
  description = "Regional health check riding the frontend (timeout defaults to interval — GCP requires timeout <= interval)."
  type = object({
    protocol = string
    port     = number
    # ⚠ MUST BE DECLARED OR TERRAFORM SILENTLY DROPS IT (object coercion).
    request_path        = optional(string)
    interval            = optional(number, 5)
    timeout             = optional(number)
    healthy_threshold   = optional(number, 2)
    unhealthy_threshold = optional(number, 2)
  })
}

variable "backends" {
  description = "Partition IGs covering this frontend (from the stack's zone × join-vector grouping). Empty is LEGAL — frontend live, VIP claimed, attach at cutover."
  type = list(object({
    group    = string
    failover = optional(bool, false)
  }))
  default  = []
  nullable = false
}

variable "next_hop_duty" {
  description = "TRUE when any 5-appliance/routes/ doc joins this frontend — flips the VIP purpose law to GCE_ENDPOINT-only (shared VIPs silently drop on next-hop paths)."
  type        = bool
  default     = false
}

variable "zonal_affinity" {
  description = "Backend-service zonal affinity (networkPassThroughLbTrafficPolicy). null = GCP default (DISABLED, zone-blind regional distribution). ⚠ SUPPORTED WITH NSI — measured 2026-08-14: STAY_WITHIN_ZONE accepted on NSI backend services, 972/972 flows zero drops, same-zone steering confirmed; the LB doc page's 'packet drops' ban is stale. Useful because CLIENT_IP_PROTO session affinity single-hots an NSI fleet (all GENEVE shares the gateway outer source)."
  type = object({
    spillover       = string
    spillover_ratio = optional(number)
  })
  default = null
}
