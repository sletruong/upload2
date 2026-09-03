# Stage 5-appliance — PALO ALTO ONLY.
#
# Active: Palo Alto VM-Series instances + the two NSI intercept fleets.
# Commented out below: Cisco C8000v instances, NCC appliance spokes,
# NCC VPC spokes, Cloud Routers, and the routing test VMs. Each block is
# preserved verbatim so it can be uncommented alongside its terraform.tfvars
# counterpart.
#
# Apply order: 1-shared → 2-fabric → 5-appliance → 8-cloudrouter
# Destroy order: 8-cloudrouter → 5-appliance → 2-fabric → 1-shared
#
# Cross-stage references:
#   VPCs (from 2-fabric)    → data.google_compute_network
#   NCC hubs (from 1-shared) → hub self_link constructed from project + hub name

# ─── Locals ────────────────────────────────────────────────────────────────────

locals {
  # One entry per Palo instance zone. Key: "{short_name}-{zone}" e.g. "cent1-a"
  # (also feeds the Cisco fleet when that family is re-enabled)
  instance_deployments = {
    for pair in flatten([
      for region, rc in var.regions : [
        for zone in rc.zones : {
          key        = "${rc.short_name}-${zone}"
          region     = region
          zone       = "${region}-${zone}"
          short_name = rc.short_name
        }
      ]
    ]) : pair.key => pair
  }

  # All zones needing NSI intercept forwarding rules (superset of instance zones).
  all_intercept_zones = {
    for pair in flatten([
      for region, rc in var.regions : [
        for zone in toset(concat(rc.zones, coalesce(rc.intercept_zones, []))) : {
          key    = "${rc.short_name}-${zone}"
          region = region
          zone   = "${region}-${zone}"
        }
      ]
    ]) : pair.key => pair
  }
}

# ─── Data Sources — VPCs (created in 2-fabric) ─────────────────────────────────
# Only the producer VPCs are needed here. Consumer VPC self_links are resolved
# in stage 6-policy, which owns the GNFP associations.

data "google_compute_network" "vpcs" {
  for_each = toset(concat(
    var.nsi_ewti_enabled ? [var.nsi_ewti_producer_vpc] : [],
    var.nsi_nsti_enabled ? [var.nsi_nsti_producer_vpc] : [],
  ))
  project = var.project_id
  name    = each.key
}

# ─── NIC Subnet Resolution ─────────────────────────────────────────────────────
# Resolves each NIC's `subnet` field into a full subnetwork self-link per
# region. Two conventions are supported:
#
#   INFIX  — subnet contains the "{region}" token, replaced with short_name:
#            "adtgcp-us-{region}-pa-mgmt"  ->  "adtgcp-us-cent1-pa-mgmt"
#   SUFFIX — no token, legacy form "{subnet}-{short_name}":
#            "wan1-s1"                     ->  "wan1-s1-usc1"
#
# One tfvars entry therefore covers every region in either scheme.

locals {
  palo_nics = {
    for dk, dv in local.instance_deployments : dk => [
      for nic in var.palo_network_interfaces : {
        subnetwork = "projects/${var.project_id}/regions/${dv.region}/subnetworks/${
          strcontains(nic.subnet, "{region}")
          ? replace(nic.subnet, "{region}", dv.short_name)
          : "${nic.subnet}-${dv.short_name}"
        }"
        create_public_ip   = nic.create_public_ip
        network_attachment = nic.network_attachment
        private_ip         = nic.private_ip
        private_ip_name    = null
      }
    ]
  }

  # NOT PALO ALTO — Cisco NIC resolution.
  # cisco_nics = {
  #   for dk, dv in local.instance_deployments : dk => [
  #     for nic in var.cisco_network_interfaces : {
  #       subnetwork = "projects/${var.project_id}/regions/${dv.region}/subnetworks/${
  #         strcontains(nic.subnet, "{region}")
  #         ? replace(nic.subnet, "{region}", dv.short_name)
  #         : "${nic.subnet}-${dv.short_name}"
  #       }"
  #       create_public_ip   = nic.create_public_ip
  #       network_attachment = nic.network_attachment
  #       private_ip         = nic.private_ip
  #     }
  #   ]
  # }
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMENTED OUT — NOT PALO ALTO: Cisco Router Instances
# ═══════════════════════════════════════════════════════════════════════════════
# Re-enabling also needs local.cisco_nics above and the cisco_* blocks in
# terraform.tfvars.
#
# module "cisco_router" {
#   # Gated on the NIC list: an empty cisco_network_interfaces disables the whole
#   # Cisco family, so the Cisco blocks can stay commented out in terraform.tfvars.
#   for_each = length(var.cisco_network_interfaces) > 0 ? local.instance_deployments : {}
#   source   = "../../../modules/gce_cisco"
#
#   name             = "${var.cisco_name}-${each.key}"
#   project_id       = var.project_id
#   zone             = each.value.zone
#   machine_type     = var.cisco_machine_type
#   min_cpu_platform = var.cisco_min_cpu_platform
#   disk_type        = var.cisco_disk_type
#   cisco_image      = var.cisco_image
#   custom_image     = null
#   service_account  = "sa-cisco@${var.project_id}.iam.gserviceaccount.com"
#   tags             = var.cisco_tags
#   labels           = var.cisco_labels
#
#   metadata = {
#     ssh-keys = "${var.cisco_username}:${trimspace(file(pathexpand(var.cisco_ssh_key_path)))}"
#   }
#
#   network_interfaces = local.cisco_nics[each.key]
# }

# ─── Palo Alto Firewall Instances ──────────────────────────────────────────────

module "palo_firewall" {
  for_each = local.instance_deployments
  source   = "../../../modules/gce_palo"

  # "{palo_name}-{short_name}-{zone}-{palo_name_suffix}" — e.g. adtgcp-cent1-a-fw-01.
  # each.key is already "{short_name}-{zone}".
  name                    = var.palo_name_suffix != "" ? "${var.palo_name}-${each.key}-${var.palo_name_suffix}" : "${var.palo_name}-${each.key}"
  project_id              = var.project_id
  zone                    = each.value.zone
  machine_type            = var.palo_machine_type
  min_cpu_platform        = var.palo_min_cpu_platform
  disk_type               = var.palo_disk_type
  palos_image             = var.palo_image
  custom_image            = null
  service_account         = "sa-palo@${var.project_id}.iam.gserviceaccount.com"
  ssh_keys                = "admin:${trimspace(file(pathexpand(var.palo_ssh_key_path)))}"
  tags                    = var.palo_tags
  labels                  = var.palo_labels
  metadata                = var.palo_metadata
  metadata_startup_script = var.palo_metadata_startup_script

  network_interfaces = local.palo_nics[each.key]
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMENTED OUT — NOT PALO ALTO: NCC Appliance Spokes (Cisco → NCC Hubs)
# ═══════════════════════════════════════════════════════════════════════════════
# Hub self_link constructed from project_id + hub name (created in 1-shared).
# One spoke per region — each includes all zone instances in that region.
# Depends on module.cisco_router, so it cannot be re-enabled on its own.
#
# module "ncc_appliance_spokes" {
#   for_each   = var.ncc_appliance_spokes
#   source     = "../../../modules/gcp_ncc_appliance_spoke"
#   project_id = var.project_id
#   region     = each.value.region
#
#   ncc_appliance_spoke = {
#     hub_name                  = "projects/${var.project_id}/locations/global/hubs/${each.value.hub_key}"
#     spoke_name                = each.key
#     enable_site_data_transfer = each.value.enable_site_data_transfer
#     instances = [
#       for iz_key, iz in local.instance_deployments : {
#         self_link  = module.cisco_router[iz_key].self_link
#         ip_address = module.cisco_router[iz_key].instance.network_interface[each.value.nic_index].network_ip
#       } if iz.region == each.value.region
#     ]
#   }
#
#   # No explicit depends_on — the self_link references above create implicit
#   # per-instance dependencies. An explicit [module.cisco_router] would block
#   # every region's spoke until every router in every region is ready, so a
#   # zone-capacity failure in one region would stop all other regions.
# }

# ═══════════════════════════════════════════════════════════════════════════════
# COMMENTED OUT — NOT PALO ALTO: NCC VPC Spokes
# ═══════════════════════════════════════════════════════════════════════════════
# module "ncc_vpc_spokes" {
#   for_each   = var.ncc_vpc_spokes
#   source     = "../../../modules/gcp_ncc_vpc_spoke"
#   project_id = var.project_id
#
#   spoke_name            = each.key
#   hub_name              = "projects/${var.project_id}/locations/global/hubs/${each.value.hub_key}"
#   network_name          = each.value.network_name
#   exclude_export_ranges = each.value.exclude_export_ranges
# }

# ═══════════════════════════════════════════════════════════════════════════════
# COMMENTED OUT — NOT PALO ALTO: Cloud Routers
# ═══════════════════════════════════════════════════════════════════════════════
# NCC hub interfaces on WAN1, WAN2, and LAN-transit VPCs.
# BGP peers (Cisco ↔ Cloud Router) are wired in stage 8-cloudrouter.
#
# module "cloud_routers" {
#   for_each     = var.cloud_routers
#   source       = "../../../modules/gcp_cloud_router"
#   project_id   = var.project_id
#   network_name = each.key
#   routers      = each.value
# }

# ─── NSI EWTI Fleet — east-west traffic (Palo NIC 1) ───────────────────────────
# Producer VPC: var.nsi_ewti_producer_vpc (adtgcp-nsi-pa-producer-01).
# Consumer VPCs and intercept rules live in stage 6-policy — see below.

module "nsi_ewti" {
  count  = var.nsi_ewti_enabled ? 1 : 0
  source = "../../../modules/gcp_nsi"

  project_id  = var.project_id
  org_id      = "45694343690"
  name_prefix = "adt-lab-ewti"

  producer_network = data.google_compute_network.vpcs[var.nsi_ewti_producer_vpc].self_link

  deployments = {
    for iz_key, iz in local.instance_deployments : iz_key => {
      zone               = iz.zone
      region             = iz.region
      instance_self_link = module.palo_firewall[iz_key].self_link
      subnetwork         = "projects/${var.project_id}/regions/${iz.region}/subnetworks/${replace(var.nsi_ewti_producer_subnet, "{region}", iz.short_name)}"
    }
  }

  intercept_zones = local.all_intercept_zones

  # consumer_networks and intercept_rules are intentionally empty.
  # GNFP associations and rules with source_network_context filtering live in
  # stage 6-policy, which runs after this stage. The module still creates the
  # full NSI plumbing: ILBs, backend services, endpoint groups, security
  # profile, and SPG (adt-lab-ewti-profile-group) that 6-policy references.
  consumer_networks = {}
  intercept_rules   = []

  health_check_port = 443

  # No explicit depends_on — instance_self_link references in the deployments map
  # create implicit per-instance dependencies. A broad [module.palo_firewall] would
  # block the entire NSI fleet until every Palo in every region is ready.
}

# ─── NSI NSTI Fleet — north-south + internet traffic (Palo NIC 2) ──────────────
# Producer VPC: var.nsi_nsti_producer_vpc (adtgcp-nsi-pa-producer-02).
# GNFP associations and rules are in stage 6-policy.

module "nsi_nsti" {
  count  = var.nsi_nsti_enabled ? 1 : 0
  source = "../../../modules/gcp_nsi"

  project_id  = var.project_id
  org_id      = "45694343690"
  name_prefix = "adt-lab-nsti"

  producer_network = data.google_compute_network.vpcs[var.nsi_nsti_producer_vpc].self_link

  deployments = {
    for iz_key, iz in local.instance_deployments : iz_key => {
      zone               = iz.zone
      region             = iz.region
      instance_self_link = module.palo_firewall[iz_key].self_link
      subnetwork         = "projects/${var.project_id}/regions/${iz.region}/subnetworks/${replace(var.nsi_nsti_producer_subnet, "{region}", iz.short_name)}"
    }
  }

  intercept_zones = local.all_intercept_zones

  # consumer_networks and intercept_rules are intentionally empty.
  # GNFP associations and rules (with INTERNET/NON_INTERNET context) live in
  # stage 6-policy. The module still creates the SPG (adt-lab-nsti-profile-group)
  # that 6-policy references.
  consumer_networks = {}
  intercept_rules   = []

  health_check_port = 443

  # No explicit depends_on — same reasoning as nsi_ewti above.
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMENTED OUT — NOT PALO ALTO: Test VMs
# ═══════════════════════════════════════════════════════════════════════════════
# Minimal Debian VMs used to verify inter-VPC routing through the Cisco fabric.
#
# resource "google_compute_instance" "test_vm" {
#   for_each = var.test_vms
#
#   name         = each.key
#   machine_type = "e2-micro"
#   zone         = each.value.zone
#   project      = var.project_id
#
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-12"
#       size  = 10
#     }
#   }
#
#   network_interface {
#     subnetwork = "projects/${var.project_id}/regions/${each.value.region}/subnetworks/${each.value.subnet}"
#   }
#
#   metadata = {
#     enable-oslogin = "TRUE"
#   }
#
#   tags = ["test-vm"]
# }
