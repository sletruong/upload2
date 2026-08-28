variable "project_id" {
  description = "The project ID where the resources will be created"
}

variable "region" {
  description = "The region where the resources will be created"
}

variable "ncc_appliance_spoke" {
  description = "List of NCC Appliance spoke configurations"
  type = object({
    hub_name                  = string
    spoke_name                = string
    enable_site_data_transfer = optional(bool, false)
    instances = list(object({
      self_link  = string
      ip_address = string
    }))
  })
}
