variable "project_id" {
  description = "Project ID"
  type        = string
}

variable "network_name" {
  description = "The name of the network"
  type        = string
}

variable "routers" {
  description = "Map of router configurations."
  type = map(object({
    # router_name = optional(string)
    region      = string
    ncc_interfaces = optional(map(object({
      subnetwork          = string
      ip_address          = string
      redundant_interface = optional(string, null)
    })), {})
    cloud_nat = optional(object({
      source_subnetwork_ip_ranges_to_nat  = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
      external_nat_ip_dynamic             = optional(bool, false)
      external_nat_ip_count               = optional(number, 0)
      external_nat_ip_list                = optional(list(string), [])
      enable_dynamic_port_allocation      = optional(bool)
      enable_endpoint_independent_mapping = optional(bool)
      tcp_established_idle_timeout_sec    = optional(number)
      log_config_enable                   = optional(bool)
      log_config_filter                   = optional(string)
      icmp_idle_timeout_sec               = optional(number)
      tcp_transitory_idle_timeout_sec     = optional(number)
      udp_idle_timeout_sec                = optional(number)
      min_ports_per_vm                    = optional(number)
      max_ports_per_vm                    = optional(number)
      rules = optional(list(object({
        description = optional(string, null)
        match       = string
        rule_number = number
        action = object({
          source_nat_active_ips = list(string)
          source_nat_drain_ips  = list(string)
        })
      })), [])
    }), {})
    bgp_spoke = optional(object({
      asn               = number
      advertise_mode    = optional(string, "CUSTOM")
      advertised_groups = optional(list(string), ["ALL_SUBNETS"])
      advertised_ip_ranges = optional(list(object({
        range       = string
        description = optional(string, null)
      })), [])
    }), { asn = null })
  }))

  validation {
    condition = (
      alltrue(
        [
          for router_id, router in var.routers :
          (router.cloud_nat.external_nat_ip_dynamic ? 1 : 0) +
          (router.cloud_nat.external_nat_ip_count > 0 ? 1 : 0) +
          (length(router.cloud_nat.external_nat_ip_list) > 0 ? 1 : 0) < 2
        ]
      )
    )
    error_message = "Only one of the following [external_nat_ip_dynamic, external_nat_ip_count, or external_nat_ip_list] may be set for each router"
  }
}
