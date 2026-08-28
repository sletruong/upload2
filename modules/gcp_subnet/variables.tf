
variable "project_id" {
  description = "The ID of the project where the routes will be created"
}

variable "network_name" {
  description = "The name of the network where routes will be created"
}

variable "subnets" {
  type = map(object({
    subnet_ip                 = string
    subnet_region             = string
    subnet_private_access     = bool
    subnet_flow_logs          = bool
    subnet_flow_logs_filter   = bool
    subnet_flow_logs_interval = string
    subnet_flow_logs_sampling = number
    subnet_flow_logs_metadata = string
    secondary_ranges = map(object({
      ip_cidr_range = string
    }))
    # only valid value INTERNAL_HTTPS_LOAD_BALANCER
    # if INTERNAL_HTTPS_LOAD_BALANCER the either ACTIVE or BACKUP
    purpose = string
    role    = string
    #	  
    iam_roles = map(object({
      role    = string
      members = list(string)
    }))
  }))
  description = "map of subnets objects."
}