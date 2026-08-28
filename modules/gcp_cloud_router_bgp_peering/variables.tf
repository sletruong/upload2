variable "project_id" {
  description = "The ID of the project where this VPC will be created"
  type        = string
}

variable "bgp_peering" {
  description = "The BGP peering configuration"
  type = object({
    instance_address   = string
    instance_asn       = number
    instance_name      = string
    instance_self_link = string
    instance_zone      = string
    subnetwork_name    = string

    ### The values below can be overridden at the peer level
    cloud_router_name = optional(string, null)                  #<-- This is the nam of the cloud router that should be used unless a more specific name is used at the peer level
    advertise_mode    = optional(string, "DEFAULT")             #<-- This is the advertise mode for the BGP peering unless a more specific mode is used at the peer level
    advertised_groups = optional(list(string), ["ALL_SUBNETS"]) #<-- This is the advertised groups for the BGP peering unless a more specific list is used at the peer level
    advertised_ip_ranges = optional(list(object({
      range       = string
      description = optional(string, null)
    })), []) #<-- This is the advertised groups for the BGP peering unless a more specific list is used at the peer level
    #### 

    peers = list(object({
      enable                  = optional(bool, true) #<-- This is the enable flag for the BGP peering
      peer_name               = optional(string, null)
      cloud_router_nic_number = optional(number, null)
      cloud_router_nic_name   = optional(string, null)
      priority                = optional(number, 100)
      cloud_router_name       = optional(string, null)       #<-- This is the name of the cloud router that should be used and overrides the cloud_router_name at the instance level if set
      advertise_mode          = optional(string, null)       #<-- This is the advertise mode for the BGP peering and overrides the advertise_mode at the instance level if set
      advertised_groups       = optional(list(string), null) #<-- This is the advertised groups for the BGP peering and overrides the advertised_groups at the instance level if set
      advertised_ip_ranges = optional(list(object({
        range       = string
        description = optional(string, null)
      }))) #<-- This is the advertised groups for the BGP peering and overrides the advertised_groups at the instance level if set
    }))
  })

  validation {
    condition     = length(var.bgp_peering.peers) > 0
    error_message = "At least one BGP peer must be configured"
  }

  validation {
    condition     = alltrue([for peer in var.bgp_peering.peers : peer.cloud_router_nic_number != null || peer.cloud_router_nic_name != null])
    error_message = "Either cloud_router_nic_number or cloud_router_nic_name must be provided for each BGP peer"
  }

  validation {
    condition     = alltrue([for peer in var.bgp_peering.peers : peer.cloud_router_name != null || var.bgp_peering.cloud_router_name != null])
    error_message = "Either cloud_router_name must be provided for each BGP peer or the cloud_router_name at the instance level must be provided"
  }
}
