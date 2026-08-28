variable "project_id" {
  type        = string
  description = "PRODUCER project. Cross-project consumers need roles/networksecurity.interceptDeploymentUser here."
}

variable "name" {
  type        = string
  description = "Deployment group name (explicit — the naming layer's contract)."
}

variable "description" {
  type    = string
  default = ""
}

variable "network" {
  type        = string
  description = "Producer VPC self-link or path — 'the network used for all child deployments'. MTU must be 8896 (GENEVE +308)."
}

variable "deployments" {
  description = <<-EOT
    Zonal deployments emitted from ILB `nsi.join` — keyed by deployment name.
    STATIC document facts only (zone), so the key set is plan-known.

    An EMPTY map is legal: the group exists and inspects nothing. GCP
    validates that the forwarding rule EXISTS, not that anything answers
    behind it, so the whole chain stands up with zero VMs.
  EOT
  type = map(object({
    zone        = string
    description = optional(string, "")
  }))
  default = {}
}

variable "deployment_forwarding_rules" {
  description = <<-EOT
    Apply-time forwarding-rule paths, keyed identically to `deployments`.

    ⚠ SPLIT FROM `deployments` ON PURPOSE. A single unknown value anywhere
    inside a map makes the WHOLE map unknown — KEYS INCLUDED — and for_each
    rejects that outright. Keeping the unknown in a SEPARATE map lets
    for_each iterate the known key set and look the unknown up by key.
  EOT
  type        = map(string)
  default     = {}
}

variable "labels" {
  type    = map(string)
  default = {}
}
