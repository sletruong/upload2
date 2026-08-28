variable "project_id" {
  description = "The VPC's project."
  type        = string
}

variable "name" {
  description = "Connector name (explicit — a CONTRACT surface: Cloud Run/Functions/App Engine configs reference it). Max 25 chars (API limit, stricter than RFC1035)."
  type        = string

  validation {
    condition     = length(var.name) <= 25
    error_message = "Connector names are capped at 25 characters (vpcaccess API limit)."
  }
}

variable "region" {
  description = "Long-form region (connectors are regional; serverless workloads must be in the same region)."
  type        = string
}

variable "network" {
  description = "Network self link — CIDR mode only (caller-resolved; null when a dedicated subnet is used)."
  type        = string
  default     = null
}

variable "ipv4_cidr" {
  description = "CIDR mode: a /28 the connector claims for its instances (must not overlap anything). Exactly one of ipv4_cidr XOR subnet."
  type        = string
  default     = null

  validation {
    condition     = (var.ipv4_cidr != null) != (var.subnet != null)
    error_message = "Exactly ONE IP mode: ipv4_cidr (/28 claimed by the connector) XOR subnet (dedicated /28 subnet)."
  }

  validation {
    condition     = var.ipv4_cidr == null || can(regex("/28$", coalesce(var.ipv4_cidr, "x")))
    error_message = "Connector CIDR mode requires exactly a /28."
  }
}

variable "subnet" {
  description = "Subnet mode: self link of a DEDICATED /28 subnet (caller-resolved from a rendered name; nothing else may use it)."
  type        = string
  default     = null
}

variable "machine_type" {
  description = "Connector instance type (throughput scaling): f1-micro | e2-micro | e2-standard-4."
  type        = string
  default     = "e2-micro"

  validation {
    condition     = contains(["f1-micro", "e2-micro", "e2-standard-4"], var.machine_type)
    error_message = "machine_type must be f1-micro, e2-micro, or e2-standard-4."
  }
}

variable "min_instances" {
  description = "Always-on floor (>=2 — connectors BILL continuously; they never scale to zero)."
  type        = number
  default     = 2

  validation {
    condition     = var.min_instances >= 2 && var.max_instances > var.min_instances
    error_message = "min_instances >= 2 and max_instances > min_instances (API constraints; connectors never scale to zero)."
  }
}

variable "max_instances" {
  description = "Scale ceiling (<=10)."
  type        = number
  default     = 3

  validation {
    condition     = var.max_instances <= 10
    error_message = "max_instances is capped at 10."
  }
}
