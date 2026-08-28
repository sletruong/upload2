variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "org_id" {
  description = "GCP organization ID for security profile and security profile group. Derived from the project if not provided."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix applied to all NSI resource names"
  type        = string
}

variable "producer_network" {
  description = "Self-link of the producer VPC where Palo Alto instances receive intercepted GENEVE traffic"
  type        = string
}

variable "deployments" {
  description = <<-EOF
    Map of Palo Alto deployments keyed by a short name (e.g. "usc1-a", "use4-b").
    One entry per zone — each deployment corresponds to one Palo Alto instance.
    subnetwork is the full self-link of the producer VPC subnet used by the ILB.
  EOF
  type = map(object({
    zone               = string
    region             = string
    instance_self_link = string
    subnetwork         = string
  }))
}

variable "intercept_zones" {
  description = <<-EOF
    Map of EVERY zone that needs an intercept deployment, keyed by a short name
    (e.g. "usc1-a", "usc1-b", "usc1-c"). Must be a superset of the zones in
    var.deployments.

    A zone without an intercept deployment fails OPEN — workloads in that zone
    are not inspected. Every zone gets its own unique forwarding rule — GCP does
    not permit sharing a forwarding rule between intercept deployments.
  EOF
  type = map(object({
    zone   = string
    region = string
  }))
}

variable "consumer_networks" {
  description = <<-EOF
    Map of consumer VPC network self-links to protect via NSI.
    Key is a short name used in resource names; value is the network self-link.
    Traffic originating from or destined to these VPCs is intercepted and sent
    to the Palo Alto firewall for inspection via GENEVE encapsulation.
  EOF
  type = map(string)
}

variable "health_check_port" {
  description = "TCP port used to health-check the Palo Alto backends through the producer VPC"
  type        = number
  default     = 22
}

variable "intercept_rules" {
  description = <<-EOF
    Network firewall policy rules that trigger traffic interception.
    Each rule sends matching traffic to Palo Alto via GENEVE for inspection.
    direction must be INGRESS or EGRESS.
    ip_protocol defaults to "all" (intercept every protocol).
    src_ranges / dest_ranges default to 0.0.0.0/0.
  EOF
  type = list(object({
    priority    = number
    direction   = string
    ip_protocol = optional(string, "all")
    src_ranges  = optional(list(string), ["0.0.0.0/0"])
    dest_ranges = optional(list(string), ["0.0.0.0/0"])
    description = optional(string, null)
  }))
  default = [
    {
      priority    = 1000
      direction   = "INGRESS"
      description = "Intercept all ingress traffic for Palo Alto inspection via GENEVE"
    },
    {
      priority    = 1001
      direction   = "EGRESS"
      description = "Intercept all egress traffic for Palo Alto inspection via GENEVE"
    }
  ]
}
