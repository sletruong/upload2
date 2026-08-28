

# ─── Locals ────────────────────────────────────────────────────────────────────

locals {
  # Flat map of all per-zone instance deployments (zones with Palo Alto / Cisco).
  # Key: "{short_name}-{zone_suffix}" e.g. "usc1-a", "usc1-b", "use4-a", "use4-b"
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

  # Flat map of ALL zones needing NSI intercept deployments.
  # Unions the Palo Alto zones with any extra intercept_zones so a zone is never missed.
  # Every zone gets its own unique forwarding rule — GCP does not permit sharing
  # a forwarding rule between intercept deployments. Zones without Palo Alto get a
  # backend service that points to all Palo Alto IGs in the same region.
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

# ─── Service Accounts ──────────────────────────────────────────────────────────

module "cisco_service_account" {
  source     = "../../modules/gcp_iam_service_account"
  project_id = var.project_id

  service_account_id = "sa-cisco"
  display_name       = "Cisco C8K Router Service Account"
  default_roles = [
    "roles/compute.networkViewer",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ]
  roles = []
}

module "palo_service_account" {
  source     = "../../modules/gcp_iam_service_account"
  project_id = var.project_id

  service_account_id = "sa-palo"
  display_name       = "Palo Alto VM-Series Service Account"
  roles              = []
}

# ─── VPCs ──────────────────────────────────────────────────────────────────────

module "vpcs" {
  for_each   = var.vpcs
  source     = "../../modules/gcp_vpc"
  project_id = var.project_id

  network_name                               = each.key
  routing_mode                               = each.value.routing_mode
  description                                = each.value.description
  delete_default_internet_gateway_routes     = each.value.delete_default_internet_gateway_routes
  mtu                                        = each.value.mtu
  network_firewall_policy_enforcement_order  = each.value.network_firewall_policy_enforcement_order
}

# ─── Subnets ───────────────────────────────────────────────────────────────────

module "subnets" {
  for_each     = var.vpc_subnets
  source       = "../../modules/gcp_subnet"
  project_id   = var.project_id
  network_name = each.key

  subnets = {
    for subnet_name, subnet in each.value : subnet_name => {
      subnet_ip                 = subnet.cidr
      subnet_region             = subnet.region
      subnet_private_access     = subnet.private_access
      subnet_flow_logs          = subnet.flow_logs
      subnet_flow_logs_filter   = false
      subnet_flow_logs_interval = "INTERVAL_5_SEC"
      subnet_flow_logs_sampling = 0.5
      subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
      secondary_ranges          = {}
      purpose                   = null
      role                      = null
      iam_roles                 = {}
    }
  }

  depends_on = [module.vpcs]
}

# ─── Firewall Rules ─────────────────────────────────────────────────────────────

module "firewall_rules" {
  for_each     = var.firewall_rules
  source       = "../../modules/gcp_firewall_rule"
  project_id   = var.project_id
  network_name = each.key
  firewall_rules = each.value

  depends_on = [module.vpcs]
}

# ─── NCC Hubs ──────────────────────────────────────────────────────────────────

module "ncc_hubs" {
  source     = "../../modules/gcp_ncc_hub"
  project_id = var.project_id
  ncc_hubs   = var.ncc_hubs
}

# ─── NCC Appliance Spokes ──────────────────────────────────────────────────────

module "ncc_appliance_spokes" {
  for_each   = var.ncc_appliance_spokes
  source     = "../../modules/gcp_ncc_appliance_spoke"
  project_id = var.project_id
  region     = each.value.region

  ncc_appliance_spoke = {
    hub_name                  = module.ncc_hubs.ncc_hub_ids[each.value.hub_key]
    spoke_name                = each.key
    enable_site_data_transfer = each.value.enable_site_data_transfer
    # Include ALL zone instances for this region so both zone-a and zone-b
    # appliances are registered in the same NCC spoke for HA.
    instances = each.value.appliance == "cisco" ? [
      for iz_key, iz in local.instance_deployments : {
        self_link  = module.cisco_router[iz_key].self_link
        ip_address = module.cisco_router[iz_key].instance.network_interface[each.value.nic_index].network_ip
      } if iz.region == each.value.region
    ] : [
      for iz_key, iz in local.instance_deployments : {
        self_link  = module.palo_firewall[iz_key].self_link
        ip_address = module.palo_firewall[iz_key].instance.network_interface[each.value.nic_index].network_ip
      } if iz.region == each.value.region
    ]
  }

  depends_on = [module.ncc_hubs, module.cisco_router, module.palo_firewall]
}

# ─── NCC VPC Spokes ────────────────────────────────────────────────────────────

module "ncc_vpc_spokes" {
  for_each   = var.ncc_vpc_spokes
  source     = "../../modules/gcp_ncc_vpc_spoke"
  project_id = var.project_id

  spoke_name            = each.key
  hub_name              = module.ncc_hubs.ncc_hub_ids[each.value.hub_key]
  network_name          = each.value.network_name
  exclude_export_ranges = each.value.exclude_export_ranges

  depends_on = [module.ncc_hubs, module.vpcs]
}

# ─── Cloud Routers ─────────────────────────────────────────────────────────────

module "cloud_routers" {
  for_each     = var.cloud_routers
  source       = "../../modules/gcp_cloud_router"
  project_id   = var.project_id
  network_name = each.key
  routers      = each.value

  depends_on = [module.vpcs, module.subnets]
}

# ─── Cisco Router ──────────────────────────────────────────────────────────────

module "cisco_router" {
  for_each = local.instance_deployments
  source   = "../../modules/gce_cisco"

  # each.key = "usc1-a" | each.value = { region, zone, short_name }
  name             = "${var.cisco_name}-${each.key}"
  project_id       = var.project_id
  zone             = each.value.zone
  machine_type     = var.cisco_machine_type
  min_cpu_platform = var.cisco_min_cpu_platform
  cisco_image      = var.cisco_image
  service_account  = module.cisco_service_account.email
  tags             = var.cisco_tags
  labels           = var.cisco_labels

  # Recipe A: ssh-keys metadata ONLY — no startup-script.
  metadata = {
    ssh-keys = "${var.cisco_username}:${trimspace(file(pathexpand(var.cisco_ssh_key_path)))}"
  }

  # Subnets are regional — both zone-a and zone-b instances share the same
  # subnet (e.g. wan1-s1-usc1). Each instance gets a different IP from the pool.
  network_interfaces = [for nic in var.cisco_network_interfaces : {
    subnetwork         = "projects/${var.project_id}/regions/${each.value.region}/subnetworks/${nic.subnet}-${each.value.short_name}"
    create_public_ip   = nic.create_public_ip
    network_attachment = nic.network_attachment
  }]

  depends_on = [module.subnets]
}

# ─── BGP Peering (Cloud Router ↔ Cisco) ────────────────────────────────────────

module "cisco_bgp_peering" {
  for_each = {
    for iz_key, iz in local.instance_deployments : iz_key => iz
    if contains(keys(var.cloud_routers), "lan-transit-vpc1")
  }
  source     = "../../modules/gcp_cloud_router_bgp_peering"
  project_id = var.project_id

  bgp_peering = {
    instance_address   = module.cisco_router[each.key].instance.network_interface[3].network_ip
    instance_asn       = var.cisco_bgp_asn
    instance_name      = module.cisco_router[each.key].instance.name
    instance_self_link = module.cisco_router[each.key].self_link
    instance_zone      = module.cisco_router[each.key].instance.zone
    subnetwork_name    = "lan-transit-vpc1-s2-${each.value.short_name}"
    cloud_router_name  = "lan-transit-vpc1-cloudrouter-1-${each.value.short_name}"

    peers = [
      { cloud_router_nic_number = 0 },
      { cloud_router_nic_number = 1 }
    ]
  }

  depends_on = [module.cloud_routers, module.cisco_router, module.ncc_appliance_spokes]
}

module "cisco_bgp_peering_wan1" {
  for_each = {
    for iz_key, iz in local.instance_deployments : iz_key => iz
    if contains(keys(var.cloud_routers), "wan1-vpc1")
  }
  source     = "../../modules/gcp_cloud_router_bgp_peering"
  project_id = var.project_id

  bgp_peering = {
    instance_address   = module.cisco_router[each.key].instance.network_interface[1].network_ip
    instance_asn       = var.cisco_bgp_asn
    instance_name      = module.cisco_router[each.key].instance.name
    instance_self_link = module.cisco_router[each.key].self_link
    instance_zone      = module.cisco_router[each.key].instance.zone
    subnetwork_name    = "wan1-s1-${each.value.short_name}"
    cloud_router_name  = "wan1-vpc1-cloudrouter-1-${each.value.short_name}"

    peers = [
      { cloud_router_nic_number = 0 },
      { cloud_router_nic_number = 1 }
    ]
  }

  depends_on = [module.cloud_routers, module.cisco_router, module.ncc_appliance_spokes]
}

module "cisco_bgp_peering_wan2" {
  for_each = {
    for iz_key, iz in local.instance_deployments : iz_key => iz
    if contains(keys(var.cloud_routers), "wan2-vpc1")
  }
  source     = "../../modules/gcp_cloud_router_bgp_peering"
  project_id = var.project_id

  bgp_peering = {
    instance_address   = module.cisco_router[each.key].instance.network_interface[2].network_ip
    instance_asn       = var.cisco_bgp_asn
    instance_name      = module.cisco_router[each.key].instance.name
    instance_self_link = module.cisco_router[each.key].self_link
    instance_zone      = module.cisco_router[each.key].instance.zone
    subnetwork_name    = "wan2-s1-${each.value.short_name}"
    cloud_router_name  = "wan2-vpc1-cloudrouter-1-${each.value.short_name}"

    peers = [
      { cloud_router_nic_number = 0 },
      { cloud_router_nic_number = 1 }
    ]
  }

  depends_on = [module.cloud_routers, module.cisco_router, module.ncc_appliance_spokes]
}

# ─── Palo Alto Firewall ─────────────────────────────────────────────────────────

module "palo_firewall" {
  for_each = local.instance_deployments
  source   = "../../modules/gce_palo"

  # each.key = "usc1-a" | each.value = { region, zone, short_name }
  name                    = "${var.palo_name}-${each.key}"
  project_id              = var.project_id
  zone                    = each.value.zone
  machine_type            = var.palo_machine_type
  min_cpu_platform        = var.palo_min_cpu_platform
  palos_image             = var.palo_image
  custom_image            = null
  service_account         = module.palo_service_account.email
  ssh_keys                = "admin:${trimspace(file(pathexpand(var.palo_ssh_key_path)))}"
  tags                    = var.palo_tags
  labels                  = var.palo_labels
  metadata                = var.palo_metadata
  metadata_startup_script = var.palo_metadata_startup_script

  network_interfaces = [for nic in var.palo_network_interfaces : {
    subnetwork         = "projects/${var.project_id}/regions/${each.value.region}/subnetworks/${nic.subnet}-${each.value.short_name}"
    create_public_ip   = nic.create_public_ip
    network_attachment = nic.network_attachment
    private_ip_name    = null
  }]

  depends_on = [module.subnets]
}

# ─── Test VMs ───────────────────────────────────────────────────────────────────

resource "google_compute_instance" "test_vm" {
  for_each = var.test_vms

  name         = each.key
  machine_type = "e2-micro"
  zone         = each.value.zone
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = "projects/${var.project_id}/regions/${each.value.region}/subnetworks/${each.value.subnet}"
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  tags = ["test-vm"]

  depends_on = [module.subnets]
}

# ─── NSI (Network Security Integration) ─────────────────────────────────────────

module "nsi" {
  count  = length(var.nsi_consumer_vpc_names) > 0 ? 1 : 0
  source = "../../modules/gcp_nsi"

  project_id  = var.project_id
  org_id      = "45694343690"
  name_prefix = var.nsi_name_prefix

  # Producer VPC: where Palo Alto NIC 0 lives (lan-mgmt-vpc via nic0)
  producer_network = module.vpcs["palo-producer-vpc1"].network_self_link

  # One ILB backend entry per Palo Alto zone instance.
  deployments = {
    for iz_key, iz in local.instance_deployments : iz_key => {
      zone               = iz.zone
      region             = iz.region
      instance_self_link = module.palo_firewall[iz_key].self_link
      subnetwork         = "projects/${var.project_id}/regions/${iz.region}/subnetworks/palo-producer-vpc1-s1-${iz.short_name}"
    }
  }

  # Every zone where consumer workloads run needs an intercept deployment.
  intercept_zones = local.all_intercept_zones

  # Consumer VPCs: traffic from these networks is intercepted and sent to Palo Alto
  consumer_networks = {
    for vpc_name in var.nsi_consumer_vpc_names : vpc_name => module.vpcs[vpc_name].network_self_link
  }

  health_check_port = 443

  intercept_rules = var.nsi_intercept_rules

  depends_on = [module.palo_firewall, module.vpcs, module.subnets]
}
