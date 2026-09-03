# ─── Shared ────────────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "regions" {
  description = "Regions to deploy into. Map key is the GCP region name."
  type = map(object({
    short_name      = string
    zone_suffix     = string
    zones           = list(string)
    intercept_zones = optional(list(string), null)
  }))
}

# ─── Cisco Router ──────────────────────────────────────────────────────────────

variable "cisco_name" {
  description = "Base name for Cisco router instances. Region short_name + zone appended per instance."
  type        = string
  # Defaulted so the Cisco family can be fully commented out of terraform.tfvars
  # without Terraform failing on a missing required variable. The Cisco module is
  # gated on cisco_network_interfaces being non-empty, not on this name.
  default = ""
}

variable "cisco_machine_type" {
  type    = string
  default = "n2-standard-4"
}

variable "cisco_disk_type" {
  description = "Boot disk type for Cisco instances. n4 machine families require hyperdisk-balanced; pd-standard is incompatible."
  type        = string
  default     = "hyperdisk-balanced"
}

variable "cisco_min_cpu_platform" {
  type    = string
  default = ""
}

variable "cisco_image" {
  type    = string
  default = "cisco-c8k-17-18-04"
}

variable "cisco_tags" {
  type    = list(string)
  default = []
}

variable "cisco_labels" {
  type    = map(string)
  default = {}
}

variable "cisco_username" {
  type    = string
  default = "admin"
}

variable "cisco_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cisco_ssh_key_path" {
  type    = string
  default = "~/.ssh/adt-lab-cisco.pub"
}

variable "cisco_bgp_asn" {
  type    = number
  default = 0
}

variable "cisco_network_interfaces" {
  description = <<-EOF
    Exactly 4 NIC definitions for the Cisco router, or an EMPTY LIST to disable
    the Cisco family entirely (module.cisco_router is gated on this).

    `subnet` supports the same "{region}" token substitution as
    palo_network_interfaces, falling back to "{subnet}-{short_name}".
  EOF
  type = list(object({
    vpc                = string
    subnet             = string
    create_public_ip   = optional(bool, false)
    network_attachment = optional(string)
    private_ip         = optional(string, null)
  }))
  default = []

  validation {
    condition     = length(var.cisco_network_interfaces) == 4 || length(var.cisco_network_interfaces) == 0
    error_message = "The Cisco router requires exactly 4 network interfaces, or 0 to disable the Cisco family."
  }
}

# ─── Palo Alto Firewall ─────────────────────────────────────────────────────────

variable "palo_name" {
  description = "Base name for Palo Alto firewall instances. Region short_name + zone are appended."
  type        = string
}

variable "palo_name_suffix" {
  description = <<-EOF
    Trailing token appended to every Palo Alto instance name, after the
    region/zone key. Full name is "{palo_name}-{short_name}-{zone}-{palo_name_suffix}"
    — e.g. palo_name="adtgcp", short_name="cent1", zone="a", suffix="fw-01"
    yields "adtgcp-cent1-a-fw-01". Set to "" to omit the suffix entirely.
  EOF
  type        = string
  default     = ""
}

variable "palo_machine_type" {
  type    = string
  default = "n2-standard-4"
}

variable "palo_disk_type" {
  description = "Boot disk type for Palo Alto instances. n4 machine families require hyperdisk-balanced; pd-standard is incompatible."
  type        = string
  default     = "hyperdisk-balanced"
}

variable "palo_min_cpu_platform" {
  type    = string
  default = ""
}

variable "palo_image" {
  type    = string
  default = "vmseries-flex-bundle3-1217"
}

variable "palo_ssh_key_path" {
  type    = string
  default = "~/.ssh/adt-lab-palo-alto.pub"
}

variable "palo_tags" {
  type    = list(string)
  default = []
}

variable "palo_labels" {
  type    = map(string)
  default = {}
}

variable "palo_metadata" {
  type    = map(string)
  default = {}
}

variable "palo_metadata_startup_script" {
  type    = string
  default = null
}

variable "palo_network_interfaces" {
  description = <<-EOF
    NIC definitions for the Palo Alto firewall. List POSITION is the GCP NIC
    index and is fixed at instance creation.

    `subnet` may contain the token "{region}", which is replaced with the
    region's short_name — so "adtgcp-us-{region}-pa-mgmt" resolves to
    "adtgcp-us-cent1-pa-mgmt" in us-central1. A `subnet` with no "{region}"
    token falls back to the legacy suffix form "{subnet}-{short_name}".

    Each NIC must attach a DIFFERENT VPC network (the GA law; same-VPC
    multi-NIC is Preview).
  EOF
  type = list(object({
    vpc                = string
    subnet             = string
    create_public_ip   = optional(bool, false)
    network_attachment = optional(string)
    private_ip         = optional(string, null)
  }))

  # Upper bound is the GCP platform maximum. The EFFECTIVE ceiling is the
  # machine shape's interface budget — ~1 per vCPU beyond 2 vCPU — which
  # Terraform cannot check here because machine_type is a separate variable.
  # 6 NICs needs >= 6 vCPU; n4-standard-4 will be rejected at create time.
  validation {
    condition     = length(var.palo_network_interfaces) >= 2 && length(var.palo_network_interfaces) <= 8
    error_message = "The Palo Alto firewall requires between 2 and 8 network interfaces (GCP platform maximum is 8, and the machine shape must have at least as many vCPUs)."
  }
}

# ─── NCC Spokes ────────────────────────────────────────────────────────────────

variable "ncc_appliance_spokes" {
  description = "NCC appliance spokes connecting Cisco NICs to NCC hubs."
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
  description = "NCC VPC spokes attaching VPC networks to NCC hubs."
  type = map(object({
    hub_key               = string
    network_name          = string
    exclude_export_ranges = optional(list(string), [])
  }))
  default = {}
}

# ─── Cloud Routers ─────────────────────────────────────────────────────────────

variable "cloud_routers" {
  description = "Cloud Routers per VPC. Outer key is VPC network name."
  type        = any
  default     = {}
}

# ─── NSI (Network Security Integration) ─────────────────────────────────────────
# Producer VPC/subnet are variables rather than literals in main.tf so the
# naming scheme lives entirely in terraform.tfvars.

variable "nsi_ewti_enabled" {
  description = <<-EOF
    Create the EWTI intercept fleet (ILBs, backend services, deployment group,
    endpoint group, security profile + SPG).

    This replaced a count gate on nsi_ewti_consumer_vpcs, which stopped being a
    valid switch once consumer_networks moved to stage 6-policy — a stage that
    needs this stage's SPG to already exist, so gating the fleet on a list this
    stage no longer consumes would deadlock the two stages.
  EOF
  type        = bool
  default     = true
}

variable "nsi_nsti_enabled" {
  description = "Create the NSTI intercept fleet. See nsi_ewti_enabled."
  type        = bool
  default     = true
}

variable "nsi_ewti_producer_vpc" {
  description = "Producer VPC network name for the EWTI fleet — the VPC on the Palo NIC that receives intercepted GENEVE traffic."
  type        = string
  default     = "adtgcp-nsi-pa-producer-01"
}

variable "nsi_ewti_producer_subnet" {
  description = "Producer subnet name for the EWTI fleet ILB. Supports the \"{region}\" token, replaced with the region short_name."
  type        = string
  default     = "adtgcp-us-{region}-nsi-pa-01"
}

variable "nsi_nsti_producer_vpc" {
  description = "Producer VPC network name for the NSTI fleet."
  type        = string
  default     = "adtgcp-nsi-pa-producer-02"
}

variable "nsi_nsti_producer_subnet" {
  description = "Producer subnet name for the NSTI fleet ILB. Supports the \"{region}\" token, replaced with the region short_name."
  type        = string
  default     = "adtgcp-us-{region}-nsi-pa-02"
}

# NOT CONSUMED BY THIS STAGE. Kept declared so the consumer inventory stays
# alongside the fleet definitions; the GNFP associations and intercept rules
# that use them live in stage 6-policy.
variable "nsi_ewti_consumer_vpcs" {
  description = "Consumer VPCs to steer to the EWTI producer VPC for east-west inspection. Read by stage 6-policy, not by this stage."
  type        = list(string)
  default     = []
}

variable "nsi_nsti_consumer_vpcs" {
  description = "Consumer VPCs to steer to the NSTI producer VPC for north-south/internet inspection. Read by stage 6-policy, not by this stage."
  type        = list(string)
  default     = []
}

# ─── Test VMs ───────────────────────────────────────────────────────────────────

variable "test_vms" {
  description = "Minimal Linux VMs for verifying inter-VPC routing."
  type = map(object({
    vpc    = string
    subnet = string
    region = string
    zone   = string
  }))
  default = {}
}
