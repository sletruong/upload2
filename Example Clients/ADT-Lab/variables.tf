# ─── Shared ────────────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID where resources will be deployed"
  type        = string
}

variable "regions" {
  description = <<-EOF
    Regions to deploy into. Map key is the GCP region name.
    short_name      : appended to subnet and resource names (e.g. "usc1", "use4").
    zone_suffix     : primary zone for non-instance resources (cloud routers, etc.).
    zones           : zone suffixes where Cisco and Palo Alto instances are deployed.
    intercept_zones : ALL zone suffixes needing NSI intercept deployments — must be a
                      superset of zones. Workloads in zones not listed here fail open.
                      Defaults to zones if not set.
  EOF
  type = map(object({
    short_name      = string
    zone_suffix     = string
    zones           = list(string)
    intercept_zones = optional(list(string), null)
  }))
}

# ─── Cisco Router ──────────────────────────────────────────────────────────────

variable "cisco_name" {
  description = "Base name for Cisco router instances. Region short_name is appended per instance."
  type        = string
}

variable "cisco_machine_type" {
  description = "Machine type for the Cisco router"
  type        = string
  default     = "n2-standard-4"
}

variable "cisco_min_cpu_platform" {
  description = "Minimum CPU platform for Cisco instances. Leave empty to let GCP infer from machine type (required for AMD-based families like n4d)."
  type        = string
  default     = ""
}

variable "cisco_image" {
  description = "Cisco image name from the cisco-public project"
  type        = string
  default     = "cisco-c8k-17-14-01a"
}

variable "cisco_tags" {
  description = "Network tags for the Cisco router"
  type        = list(string)
  default     = []
}

variable "cisco_labels" {
  description = "Resource labels for the Cisco router"
  type        = map(string)
  default     = {}
}

variable "cisco_username" {
  description = "Admin username configured on the Cisco router at bootstrap."
  type        = string
  default     = "admin"
}

variable "cisco_password" {
  description = "Password for the Cisco router admin user. Set via TF_VAR_cisco_password in .env — never hardcode."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cisco_ssh_key_path" {
  description = <<-EOF
    Path to the ED25519 private key used for Cisco C8000v SSH access (without .pub extension).
    The matching public key ({path}.pub) is uploaded to the instance at creation time.
    Generate once with:
      ssh-keygen -t ed25519 -f <path> -N ''
  EOF
  type    = string
  default = "~/.ssh/adt-lab-cisco.pub"
}

variable "cisco_network_interfaces" {
  description = <<-EOF
    Exactly 4 NIC definitions for the Cisco router.
    subnet is the base subnet name without region suffix — the region short_name is
    appended automatically, so "wan1-subnet1" resolves to "wan1-subnet1-usc1" in
    us-central1 and "wan1-subnet1-use4" in us-east4.
  EOF
  type = list(object({
    vpc                = string
    subnet             = string
    create_public_ip   = optional(bool, false)
    network_attachment = optional(string)
  }))

  validation {
    condition     = length(var.cisco_network_interfaces) == 4
    error_message = "The Cisco router requires exactly 4 network interfaces."
  }
}

variable "cisco_bgp_asn" {
  description = "BGP ASN configured on the Cisco C8K router, used as peer_asn by the Cloud Routers."
  type        = number
}

# ─── Palo Alto Firewall ─────────────────────────────────────────────────────────

variable "palo_name" {
  description = "Base name for Palo Alto firewall instances. Region short_name is appended per instance."
  type        = string
}

variable "palo_min_cpu_platform" {
  description = "Minimum CPU platform for Palo Alto instances. Leave empty to let GCP infer from machine type (required for AMD-based families like n4d)."
  type        = string
  default     = ""
}

variable "palo_machine_type" {
  description = "Machine type for the Palo Alto firewall"
  type        = string
  default     = "n2-standard-4"
}

variable "palo_image" {
  description = "VM-Series image name from the paloaltonetworksgcp-public project"
  type        = string
  default     = "vmseries-flex-byol-1110"
}

variable "palo_ssh_key_path" {
  description = <<-EOF
    Path to the ED25519 private key used for Palo Alto SSH access (without .pub extension).
    The matching public key ({path}.pub) is uploaded to the instance at creation time.
    Generate once with:
      ssh-keygen -t ed25519 -f <path> -N ''
  EOF
  type    = string
  default = "~/.ssh/adt-lab-palo-alto.pub"
}

variable "palo_tags" {
  description = "Network tags for the Palo Alto firewall"
  type        = list(string)
  default     = []
}

variable "palo_labels" {
  description = "Resource labels for the Palo Alto firewall"
  type        = map(string)
  default     = {}
}

variable "palo_network_interfaces" {
  description = <<-EOF
    NIC definitions for the Palo Alto firewall (2–4 NICs).
    subnet is the base subnet name without region suffix — the region short_name is
    appended automatically (same convention as cisco_network_interfaces).
  EOF
  type = list(object({
    vpc                = string
    subnet             = string
    create_public_ip   = optional(bool, false)
    network_attachment = optional(string)
  }))

  validation {
    condition     = length(var.palo_network_interfaces) >= 2 && length(var.palo_network_interfaces) <= 4
    error_message = "The Palo Alto firewall requires between 2 and 4 network interfaces."
  }
}

variable "palo_metadata" {
  description = "Bootstrap and instance metadata for the Palo Alto firewall. These are first-boot-only on VM-Series — changes require destroy + recreate."
  type        = map(string)
  default     = {}
}

variable "palo_metadata_startup_script" {
  description = "Startup script for the Palo Alto firewall instance (YAML bootstrap config passed via metadata_startup_script)."
  type        = string
  default     = null
}

# ─── Network (VPCs, Subnets, NCC, Cloud Routers, Firewall) ────────────────────

variable "vpcs" {
  description = "VPCs to create. Map key becomes the GCP network_name."
  type = map(object({
    routing_mode                               = optional(string, "GLOBAL")
    description                                = optional(string, "")
    delete_default_internet_gateway_routes     = optional(bool, false)
    mtu                                        = optional(number, 0)
    network_firewall_policy_enforcement_order  = optional(string, "BEFORE_CLASSIC_FIREWALL")
  }))
  default = {}
}

variable "vpc_subnets" {
  description = <<-EOF
    Subnets per VPC. Outer key is the VPC network_name; inner key is the subnet name.
    Each subnet requires an explicit region — subnets for both regions are listed
    together under the same VPC key, differentiated by name (e.g. -usc1 / -use4 suffix).
  EOF
  type = map(map(object({
    cidr           = string
    region         = string
    private_access = optional(bool, true)
    flow_logs      = optional(bool, false)
  })))
  default = {}
}

variable "ncc_hubs" {
  description = "NCC hubs to create. Map key is the hub identifier used in spoke references."
  type = map(object({
    ncc_hub_name = string
    description  = optional(string, "")
  }))
  default = {}
}

variable "ncc_appliance_spokes" {
  description = <<-EOF
    NCC appliance spokes connecting a Cisco or Palo NIC to an NCC hub.
    hub_key must match a key in var.ncc_hubs.
    appliance is "cisco" or "palo".
    region must match a key in var.regions.
    nic_index is the 0-based NIC position in the respective network_interfaces list.
  EOF
  type = map(object({
    hub_key                   = string
    appliance                 = string
    region                    = string
    nic_index                 = number
    enable_site_data_transfer = optional(bool, false)
  }))
  default = {}
}

variable "ncc_vpc_spokes" {
  description = <<-EOF
    NCC VPC spokes attaching a VPC network directly to an NCC hub.
    hub_key must match a key in var.ncc_hubs.
    network_name is the VPC network name in this project.
  EOF
  type = map(object({
    hub_key               = string
    network_name          = string
    exclude_export_ranges = optional(list(string), [])
  }))
  default = {}
}

variable "cloud_routers" {
  description = <<-EOF
    Cloud Routers per VPC for BGP peering with Cisco appliances.
    Outer key is the VPC network name; inner map is the routers config passed to the gcp_cloud_router module.
  EOF
  type    = any
  default = {}
}

variable "firewall_rules" {
  description = "Firewall rules per VPC network. Outer key is the VPC network name."
  type = map(map(object({
    description             = optional(string, null)
    direction               = optional(string, "INGRESS")
    priority                = optional(number, null)
    ranges                  = optional(list(string), [])
    source_tags             = optional(list(string))
    source_service_accounts = optional(list(string))
    target_tags             = optional(list(string))
    target_service_accounts = optional(list(string))
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    log_config = optional(list(map(string)))
  })))
  default = {}
}

# ─── Test VMs ───────────────────────────────────────────────────────────────────

variable "test_vms" {
  description = "Minimal Linux VMs for verifying inter-VPC routing. One per VPC under test."
  type = map(object({
    vpc    = string
    subnet = string
    region = string
    zone   = string
  }))
  default = {}
}

# ─── NSI (Network Security Integration) ─────────────────────────────────────────

variable "nsi_name_prefix" {
  description = "Name prefix for all NSI resources (deployment group, endpoint group, firewall policy, etc.)"
  type        = string
  default     = "nsi"
}

variable "nsi_consumer_vpc_names" {
  description = <<-EOF
    List of VPC names whose traffic will be intercepted and sent to Palo Alto for inspection.
    Each VPC must exist in var.vpcs. Leave empty to disable NSI.
  EOF
  type    = list(string)
  default = []
}

variable "nsi_intercept_rules" {
  description = "Firewall policy rules that trigger GENEVE interception. Defaults to all traffic both directions."
  type = list(object({
    priority    = number
    direction   = string
    ip_protocol = optional(string, "all")
    src_ranges  = optional(list(string), ["0.0.0.0/0"])
    dest_ranges = optional(list(string), ["0.0.0.0/0"])
    description = optional(string, null)
  }))
  default = []
}
