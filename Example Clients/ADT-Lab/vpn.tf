# ═══════════════════════════════════════════════════════════════════════════════
# HA VPN Configuration
# ───────────────────────────────────────────────────────────────────────────────
# Topology:
#
#   wan1-vpc1 ──HA VPN Link 1──► non-prod GCP project  (simulated DC, 10.10.0.0/16)
#   wan2-vpc1 ──HA VPN Link 2──► non-prod GCP project  (simulated DC, 10.10.0.0/16)
#   wan2-vpc1 ──HA VPN ────────► AWS us-east-1         (commented out — not yet authorized)
#
# BGP ASNs:
#   wan1 VPN Cloud Router (→ non-prod)  : 65101
#   wan2 VPN Cloud Router (→ non-prod)  : 65102
#   non-prod Cloud Router (wan1 peer)   : 65201
#   non-prod Cloud Router (wan2 peer)   : 65202
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Providers ─────────────────────────────────────────────────────────────────

provider "google" {
  alias                 = "nonprod"
  project               = var.nonprod_project_id
  billing_project       = var.nonprod_project_id
  user_project_override = true
}

# AWS provider — commented out until authorized
# provider "aws" {
#   region = var.aws_region
# }

# ─── Variables ─────────────────────────────────────────────────────────────────

variable "nonprod_project_id" {
  description = "GCP project ID for the simulated on-prem data centre"
  type        = string
  default     = "non-prod-gaurav-maheshwari"
}

variable "cluster2_cidr_ranges" {
  description = "Specific subnet CIDRs of vpc-cluster2. Used for WAN1 ingress firewall rule."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.101.0/24"]
}

variable "cluster3_cidr_ranges" {
  description = "Specific subnet CIDRs of vpc-cluster3. Used for WAN2 ingress firewall rule."
  type        = list(string)
  default     = ["10.21.1.0/24", "10.21.101.0/24"]
}

# variable "aws_region" {
#   description = "AWS region where the simulated on-prem site lives"
#   type        = string
#   default     = "us-east-1"
# }

# ─── Pre-shared Keys ───────────────────────────────────────────────────────────

resource "random_password" "psk_wan1_nonprod" {
  length  = 32
  special = false
}

resource "random_password" "psk_wan2_nonprod" {
  length  = 32
  special = false
}

# AWS PSKs — commented out until authorized
# resource "random_password" "psk_wan2_aws" {
#   count   = 4
#   length  = 32
#   special = false
# }

# ─── BGP link-local IP plan ────────────────────────────────────────────────────

locals {
  bgp = {
    # wan1 ↔ non-prod onprem-dc-vpc (2 tunnels)
    wan1_nonprod = {
      "0" = { current = "169.254.1.1", peer = "169.254.1.2", cidr = "169.254.1.0/30" }
      "1" = { current = "169.254.1.5", peer = "169.254.1.6", cidr = "169.254.1.4/30" }
    }
    # wan2 ↔ non-prod onprem-dc-vpc (2 tunnels)
    wan2_nonprod = {
      "0" = { current = "169.254.2.1", peer = "169.254.2.2", cidr = "169.254.2.0/30" }
      "1" = { current = "169.254.2.5", peer = "169.254.2.6", cidr = "169.254.2.4/30" }
    }
  }

  # wan2 ↔ AWS BGP plan — commented out until authorized
  # wan2_aws = {
  #   "if0-t0" = { gcp_if = 0, aws_if = 0, current = "169.254.10.1",  peer = "169.254.10.2",  inside_cidr = "169.254.10.0/30",  psk_idx = 0 }
  #   "if0-t1" = { gcp_if = 0, aws_if = 1, current = "169.254.10.5",  peer = "169.254.10.6",  inside_cidr = "169.254.10.4/30",  psk_idx = 1 }
  #   "if1-t2" = { gcp_if = 1, aws_if = 2, current = "169.254.10.9",  peer = "169.254.10.10", inside_cidr = "169.254.10.8/30",  psk_idx = 2 }
  #   "if1-t3" = { gcp_if = 1, aws_if = 3, current = "169.254.10.13", peer = "169.254.10.14", inside_cidr = "169.254.10.12/30", psk_idx = 3 }
  # }
}

# ═══════════════════════════════════════════════════════════════════════════════
# NON-PROD GCP PROJECT  —  Simulated On-Premises Data Centre
# ═══════════════════════════════════════════════════════════════════════════════

resource "google_compute_network" "nonprod_vpc" {
  provider                = google.nonprod
  project                 = var.nonprod_project_id
  name                    = "onprem-dc-vpc"
  auto_create_subnetworks = false
  description             = "Simulated DC — 10.10.0.0/16"
}

resource "google_compute_subnetwork" "nonprod_usc1" {
  provider                 = google.nonprod
  project                  = var.nonprod_project_id
  name                     = "onprem-dc-s1-usc1"
  ip_cidr_range            = "10.10.1.0/24"
  region                   = "us-central1"
  network                  = google_compute_network.nonprod_vpc.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "nonprod_use4" {
  provider                 = google.nonprod
  project                  = var.nonprod_project_id
  name                     = "onprem-dc-s1-use4"
  ip_cidr_range            = "10.10.101.0/24"
  region                   = "us-east4"
  network                  = google_compute_network.nonprod_vpc.id
  private_ip_google_access = true
}

# Cloud Routers — one per WAN link
resource "google_compute_router" "nonprod_wan1_cr" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "nonprod-wan1-cloudrouter-usc1"
  network  = google_compute_network.nonprod_vpc.id
  region   = "us-central1"
  bgp {
    asn            = 65201
    advertise_mode = "DEFAULT"
  }
}

resource "google_compute_router" "nonprod_wan2_cr" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "nonprod-wan2-cloudrouter-usc1"
  network  = google_compute_network.nonprod_vpc.id
  region   = "us-central1"
  bgp {
    asn            = 65202
    advertise_mode = "DEFAULT"
  }
}

# HA VPN Gateways — one per WAN link
resource "google_compute_ha_vpn_gateway" "nonprod_wan1_gw" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "nonprod-wan1-ha-vpn-usc1"
  network  = google_compute_network.nonprod_vpc.id
  region   = "us-central1"
}

resource "google_compute_ha_vpn_gateway" "nonprod_wan2_gw" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "nonprod-wan2-ha-vpn-usc1"
  network  = google_compute_network.nonprod_vpc.id
  region   = "us-central1"
}

# VPN Tunnels — non-prod side
resource "google_compute_vpn_tunnel" "nonprod_to_wan1" {
  for_each = local.bgp.wan1_nonprod
  provider = google.nonprod
  project  = var.nonprod_project_id

  name                  = "nonprod-to-wan1-tunnel-${each.key}"
  region                = "us-central1"
  vpn_gateway           = google_compute_ha_vpn_gateway.nonprod_wan1_gw.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.wan1_to_nonprod_gw.id
  vpn_gateway_interface = tonumber(each.key)
  shared_secret         = random_password.psk_wan1_nonprod.result
  router                = google_compute_router.nonprod_wan1_cr.id
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "nonprod_to_wan2" {
  for_each = local.bgp.wan2_nonprod
  provider = google.nonprod
  project  = var.nonprod_project_id

  name                  = "nonprod-to-wan2-tunnel-${each.key}"
  region                = "us-central1"
  vpn_gateway           = google_compute_ha_vpn_gateway.nonprod_wan2_gw.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.wan2_to_nonprod_gw.id
  vpn_gateway_interface = tonumber(each.key)
  shared_secret         = random_password.psk_wan2_nonprod.result
  router                = google_compute_router.nonprod_wan2_cr.id
  ike_version           = 2
}

# BGP Router Interfaces — non-prod side
resource "google_compute_router_interface" "nonprod_wan1_if" {
  for_each = local.bgp.wan1_nonprod
  provider = google.nonprod
  project  = var.nonprod_project_id

  name       = "nonprod-wan1-if-${each.key}"
  router     = google_compute_router.nonprod_wan1_cr.name
  region     = "us-central1"
  ip_range   = "${each.value.peer}/${split("/", each.value.cidr)[1]}"
  vpn_tunnel = google_compute_vpn_tunnel.nonprod_to_wan1[each.key].name
}

resource "google_compute_router_peer" "nonprod_wan1_peer" {
  for_each = local.bgp.wan1_nonprod
  provider = google.nonprod
  project  = var.nonprod_project_id

  name            = "nonprod-wan1-peer-${each.key}"
  router          = google_compute_router.nonprod_wan1_cr.name
  region          = "us-central1"
  interface       = google_compute_router_interface.nonprod_wan1_if[each.key].name
  peer_ip_address = each.value.current
  peer_asn        = 65101
}

resource "google_compute_router_interface" "nonprod_wan2_if" {
  for_each = local.bgp.wan2_nonprod
  provider = google.nonprod
  project  = var.nonprod_project_id

  name       = "nonprod-wan2-if-${each.key}"
  router     = google_compute_router.nonprod_wan2_cr.name
  region     = "us-central1"
  ip_range   = "${each.value.peer}/${split("/", each.value.cidr)[1]}"
  vpn_tunnel = google_compute_vpn_tunnel.nonprod_to_wan2[each.key].name
}

resource "google_compute_router_peer" "nonprod_wan2_peer" {
  for_each = local.bgp.wan2_nonprod
  provider = google.nonprod
  project  = var.nonprod_project_id

  name            = "nonprod-wan2-peer-${each.key}"
  router          = google_compute_router.nonprod_wan2_cr.name
  region          = "us-central1"
  interface       = google_compute_router_interface.nonprod_wan2_if[each.key].name
  peer_ip_address = each.value.current
  peer_asn        = 65102
}

# Firewall — allow traffic from current project into non-prod DC
resource "google_compute_firewall" "nonprod_allow_from_prod" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "nonprod-allow-from-prod"
  network  = google_compute_network.nonprod_vpc.name

  direction = "INGRESS"
  priority  = 1000

  allow { protocol = "all" }

  source_ranges = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
  ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# CURRENT PROJECT  —  WAN VPN Gateways and Cloud Routers
# ═══════════════════════════════════════════════════════════════════════════════

# ─── WAN1: HA VPN Link 1 → non-prod project ────────────────────────────────────

resource "google_compute_ha_vpn_gateway" "wan1_to_nonprod_gw" {
  project = var.project_id
  name    = "wan1-ha-vpn-to-nonprod-usc1"
  network = module.vpcs["wan1-vpc1"].network_self_link
  region  = "us-central1"
}

resource "google_compute_router" "wan1_vpn_cr" {
  project = var.project_id
  name    = "wan1-vpn-cloudrouter-usc1"
  network = module.vpcs["wan1-vpc1"].network_self_link
  region  = "us-central1"
  bgp {
    asn            = 65101
    advertise_mode = "DEFAULT"
  }
}

resource "google_compute_vpn_tunnel" "wan1_to_nonprod" {
  for_each = local.bgp.wan1_nonprod
  project  = var.project_id

  name                  = "wan1-to-nonprod-tunnel-${each.key}"
  region                = "us-central1"
  vpn_gateway           = google_compute_ha_vpn_gateway.wan1_to_nonprod_gw.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.nonprod_wan1_gw.id
  vpn_gateway_interface = tonumber(each.key)
  shared_secret         = random_password.psk_wan1_nonprod.result
  router                = google_compute_router.wan1_vpn_cr.id
  ike_version           = 2
}

resource "google_compute_router_interface" "wan1_vpn_if" {
  for_each = local.bgp.wan1_nonprod
  project  = var.project_id

  name       = "wan1-vpn-if-${each.key}"
  router     = google_compute_router.wan1_vpn_cr.name
  region     = "us-central1"
  ip_range   = "${each.value.current}/${split("/", each.value.cidr)[1]}"
  vpn_tunnel = google_compute_vpn_tunnel.wan1_to_nonprod[each.key].name
}

resource "google_compute_router_peer" "wan1_vpn_peer" {
  for_each = local.bgp.wan1_nonprod
  project  = var.project_id

  name            = "wan1-vpn-peer-${each.key}"
  router          = google_compute_router.wan1_vpn_cr.name
  region          = "us-central1"
  interface       = google_compute_router_interface.wan1_vpn_if[each.key].name
  peer_ip_address = each.value.peer
  peer_asn        = 65201
}

# ─── WAN2: HA VPN Link 2 → non-prod project ────────────────────────────────────

resource "google_compute_ha_vpn_gateway" "wan2_to_nonprod_gw" {
  project = var.project_id
  name    = "wan2-ha-vpn-to-nonprod-usc1"
  network = module.vpcs["wan2-vpc1"].network_self_link
  region  = "us-central1"
}

resource "google_compute_router" "wan2_vpn_cr" {
  project = var.project_id
  name    = "wan2-vpn-cloudrouter-usc1"
  network = module.vpcs["wan2-vpc1"].network_self_link
  region  = "us-central1"
  bgp {
    asn            = 65102
    advertise_mode = "DEFAULT"
  }
}

resource "google_compute_vpn_tunnel" "wan2_to_nonprod" {
  for_each = local.bgp.wan2_nonprod
  project  = var.project_id

  name                  = "wan2-to-nonprod-tunnel-${each.key}"
  region                = "us-central1"
  vpn_gateway           = google_compute_ha_vpn_gateway.wan2_to_nonprod_gw.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.nonprod_wan2_gw.id
  vpn_gateway_interface = tonumber(each.key)
  shared_secret         = random_password.psk_wan2_nonprod.result
  router                = google_compute_router.wan2_vpn_cr.id
  ike_version           = 2
}

resource "google_compute_router_interface" "wan2_vpn_if" {
  for_each = local.bgp.wan2_nonprod
  project  = var.project_id

  name       = "wan2-vpn-if-${each.key}"
  router     = google_compute_router.wan2_vpn_cr.name
  region     = "us-central1"
  ip_range   = "${each.value.current}/${split("/", each.value.cidr)[1]}"
  vpn_tunnel = google_compute_vpn_tunnel.wan2_to_nonprod[each.key].name
}

resource "google_compute_router_peer" "wan2_vpn_peer" {
  for_each = local.bgp.wan2_nonprod
  project  = var.project_id

  name            = "wan2-vpn-peer-${each.key}"
  router          = google_compute_router.wan2_vpn_cr.name
  region          = "us-central1"
  interface       = google_compute_router_interface.wan2_vpn_if[each.key].name
  peer_ip_address = each.value.peer
  peer_asn        = 65202
}

# Firewall — allow ingress from non-prod DC into WAN VPCs
resource "google_compute_firewall" "wan1_allow_from_nonprod" {
  project       = var.project_id
  name          = "wan1-allow-from-nonprod"
  network       = module.vpcs["wan1-vpc1"].network_self_link
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.10.0.0/16"]
  allow { protocol = "all" }
}

resource "google_compute_firewall" "wan2_allow_from_nonprod" {
  project       = var.project_id
  name          = "wan2-allow-from-nonprod"
  network       = module.vpcs["wan2-vpc1"].network_self_link
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.10.0.0/16"]
  allow { protocol = "all" }
}

# ═══════════════════════════════════════════════════════════════════════════════
# NON-PROD VPC-CLUSTER2 → WAN1 and VPC-CLUSTER3 → WAN2
# ═══════════════════════════════════════════════════════════════════════════════

resource "random_password" "psk_cluster2_wan1" {
  length  = 32
  special = false
}

resource "random_password" "psk_cluster3_wan2" {
  length  = 32
  special = false
}

# ─── Data sources — look up existing cluster VPCs in non-prod project ──────────

data "google_compute_network" "nonprod_cluster2" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "vpc-cluster2"
}

data "google_compute_network" "nonprod_cluster3" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "vpc-cluster3"
}

# ─── Subnets — vpc-cluster2 (10.20.0.0/16) ────────────────────────────────────
# Supernet: 10.20.0.0/15 covers both cluster2 and cluster3 for BGP advertisement
#
# Naming convention mirrors existing project: .1.0/24 = usc1, .101.0/24 = use4

resource "google_compute_subnetwork" "cluster2_usc1" {
  provider                 = google.nonprod
  project                  = var.nonprod_project_id
  name                     = "vpc-cluster2-s1-usc1"
  ip_cidr_range            = "10.20.1.0/24"
  region                   = "us-central1"
  network                  = data.google_compute_network.nonprod_cluster2.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "cluster2_use4" {
  provider                 = google.nonprod
  project                  = var.nonprod_project_id
  name                     = "vpc-cluster2-s1-use4"
  ip_cidr_range            = "10.20.101.0/24"
  region                   = "us-east4"
  network                  = data.google_compute_network.nonprod_cluster2.id
  private_ip_google_access = true
}

# ─── Subnets — vpc-cluster3 (10.21.0.0/16) ────────────────────────────────────

resource "google_compute_subnetwork" "cluster3_usc1" {
  provider                 = google.nonprod
  project                  = var.nonprod_project_id
  name                     = "vpc-cluster3-s1-usc1"
  ip_cidr_range            = "10.21.1.0/24"
  region                   = "us-central1"
  network                  = data.google_compute_network.nonprod_cluster3.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "cluster3_use4" {
  provider                 = google.nonprod
  project                  = var.nonprod_project_id
  name                     = "vpc-cluster3-s1-use4"
  ip_cidr_range            = "10.21.101.0/24"
  region                   = "us-east4"
  network                  = data.google_compute_network.nonprod_cluster3.id
  private_ip_google_access = true
}

# ═══════════════════════════════════════════════════════════════════════════════
# TEST VMs — rteller-demo-svc-e265-aaac (main project)
# ───────────────────────────────────────────────────────────────────────────────
# VMs live in wan1-vpc1 and wan2-vpc1 — the VPN endpoints — so they can
# directly test reachability to vpc-cluster2 and vpc-cluster3 via the tunnels.
# 4 zones in us-central1 (a/b/c/f) + 3 zones in us-east4 (a/b/c) = 7 per VPC.
# ═══════════════════════════════════════════════════════════════════════════════

locals {
  test_vm_ssh_key = "admin:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC8FELIfKRbg+86utPvckmnRJMrE2tCU9a1OLGg0xvvIXQ0pAG2Siuu4854s5uHpfL/QkkxAP4wfPzXyY8wKOwndAgibKkzNQ/LdmAzWFWsFDUyRfk4GsMlcR/IqK4vlcjBHB2Wzyv9kalnbj5WdVJwSab0oRYj/Id4Ltrfj3SGQfNPkgbONM/3GhAUmhxuEGjqGt5BGDVq9lvHTYrF5kEziMI5awZaf5pM2v1fQrIdG+kIMDSXIJE2EuXsXiJExNQHn5uqFhPa/kEPUxKCxVaXk9ueMDwu5af24zSttE0KU/BfXqrAwhUte5aO5TAIbk0J70ATNnYfH8LJ7/F+EhNFhMdQ5ekzrFaEFqGinDItkOogaPrX/eJZ/28PRxy2UxZsQ7xtuccdwUj31ut3nRaA+Ll8++4yX3qQpZs6Vww6q5je5Bu1UtTfpdrpINJcxfasU4P33ZG/Sg2x2KJY/EJvGIzKPikhZe3t4e3wXJOsXR5iFYlWZ5dFnvSHaFHTNA0= admin"

  wan1_test_vms = {
    "usc1-a" = { zone = "us-central1-a", subnetwork = "projects/${var.project_id}/regions/us-central1/subnetworks/wan1-s1-usc1" }
    "usc1-b" = { zone = "us-central1-b", subnetwork = "projects/${var.project_id}/regions/us-central1/subnetworks/wan1-s1-usc1" }
    "usc1-c" = { zone = "us-central1-c", subnetwork = "projects/${var.project_id}/regions/us-central1/subnetworks/wan1-s1-usc1" }
    "usc1-f" = { zone = "us-central1-f", subnetwork = "projects/${var.project_id}/regions/us-central1/subnetworks/wan1-s1-usc1" }
    "use4-a" = { zone = "us-east4-a",    subnetwork = "projects/${var.project_id}/regions/us-east4/subnetworks/wan1-s1-use4" }
    "use4-b" = { zone = "us-east4-b",    subnetwork = "projects/${var.project_id}/regions/us-east4/subnetworks/wan1-s1-use4" }
    "use4-c" = { zone = "us-east4-c",    subnetwork = "projects/${var.project_id}/regions/us-east4/subnetworks/wan1-s1-use4" }
  }

  wan2_test_vms = {
    "usc1-a" = { zone = "us-central1-a", subnetwork = "projects/${var.project_id}/regions/us-central1/subnetworks/wan2-s1-usc1" }
    "usc1-b" = { zone = "us-central1-b", subnetwork = "projects/${var.project_id}/regions/us-central1/subnetworks/wan2-s1-usc1" }
    "usc1-c" = { zone = "us-central1-c", subnetwork = "projects/${var.project_id}/regions/us-central1/subnetworks/wan2-s1-usc1" }
    "usc1-f" = { zone = "us-central1-f", subnetwork = "projects/${var.project_id}/regions/us-central1/subnetworks/wan2-s1-usc1" }
    "use4-a" = { zone = "us-east4-a",    subnetwork = "projects/${var.project_id}/regions/us-east4/subnetworks/wan2-s1-use4" }
    "use4-b" = { zone = "us-east4-b",    subnetwork = "projects/${var.project_id}/regions/us-east4/subnetworks/wan2-s1-use4" }
    "use4-c" = { zone = "us-east4-c",    subnetwork = "projects/${var.project_id}/regions/us-east4/subnetworks/wan2-s1-use4" }
  }
}

# ─── Test Instances — wan1-vpc1 (rteller) ─────────────────────────────────────

resource "google_compute_instance" "wan1_test" {
  for_each     = local.wan1_test_vms
  project      = var.project_id
  name         = "test-vm-wan1-${each.key}"
  machine_type = "e2-micro"
  zone         = each.value.zone
  tags         = ["wan1-test"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = each.value.subnetwork
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    ssh-keys = local.test_vm_ssh_key
  }
}

# ─── Test Instances — wan2-vpc1 (rteller) ─────────────────────────────────────

resource "google_compute_instance" "wan2_test" {
  for_each     = local.wan2_test_vms
  project      = var.project_id
  name         = "test-vm-wan2-${each.key}"
  machine_type = "e2-micro"
  zone         = each.value.zone
  tags         = ["wan2-test"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = each.value.subnetwork
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    ssh-keys = local.test_vm_ssh_key
  }
}

# ─── Firewall — IAP SSH access to test VMs in main project ────────────────────

resource "google_compute_firewall" "wan1_allow_iap_test" {
  project       = var.project_id
  name          = "wan1-allow-iap-test-ssh"
  network       = module.vpcs["wan1-vpc1"].network_self_link
  direction     = "INGRESS"
  priority      = 1000
  target_tags   = ["wan1-test"]
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "wan2_allow_iap_test" {
  project       = var.project_id
  name          = "wan2-allow-iap-test-ssh"
  network       = module.vpcs["wan2-vpc1"].network_self_link
  direction     = "INGRESS"
  priority      = 1000
  target_tags   = ["wan2-test"]
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ─── Firewall — allow ping / SSH / 443 over VPN ───────────────────────────────
# cluster2 is connected to wan1-vpc1; cluster3 is connected to wan2-vpc1.
# Source ranges are the exact /24 subnets configured in each VPC — no broad
# RFC 1918 wildcards. IAP range lets engineers ssh via "gcloud compute ssh".
#
# wan1-vpc1 subnets  : 10.0.1.0/24, 10.0.2.0/24, 10.0.101.0/24, 10.0.102.0/24
# wan2-vpc1 subnets  : 10.0.11.0/24, 10.0.12.0/24, 10.0.111.0/24, 10.0.112.0/24
# onprem-dc-vpc subs : 10.10.1.0/24, 10.10.101.0/24  (routes via WAN BGP)

resource "google_compute_firewall" "cluster2_allow_vpn" {
  provider      = google.nonprod
  project       = var.nonprod_project_id
  name          = "cluster2-allow-vpn-test"
  network       = data.google_compute_network.nonprod_cluster2.id
  direction     = "INGRESS"
  priority      = 1000
  target_tags   = ["cluster2-test"]
  source_ranges = [
    # wan1-vpc1 subnets (VPN peer for vpc-cluster2)
    "10.0.1.0/24", "10.0.2.0/24",
    "10.0.101.0/24", "10.0.102.0/24",
    # onprem-dc-vpc subnets (reaches cluster2 via wan1 BGP)
    "10.10.1.0/24", "10.10.101.0/24",
  ]

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }
}

resource "google_compute_firewall" "cluster2_allow_iap" {
  provider      = google.nonprod
  project       = var.nonprod_project_id
  name          = "cluster2-allow-iap-ssh"
  network       = data.google_compute_network.nonprod_cluster2.id
  direction     = "INGRESS"
  priority      = 1000
  target_tags   = ["cluster2-test"]
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "cluster3_allow_vpn" {
  provider      = google.nonprod
  project       = var.nonprod_project_id
  name          = "cluster3-allow-vpn-test"
  network       = data.google_compute_network.nonprod_cluster3.id
  direction     = "INGRESS"
  priority      = 1000
  target_tags   = ["cluster3-test"]
  source_ranges = [
    # wan2-vpc1 subnets (VPN peer for vpc-cluster3)
    "10.0.11.0/24", "10.0.12.0/24",
    "10.0.111.0/24", "10.0.112.0/24",
    # onprem-dc-vpc subnets (reaches cluster3 via wan2 BGP)
    "10.10.1.0/24", "10.10.101.0/24",
  ]

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }
}

resource "google_compute_firewall" "cluster3_allow_iap" {
  provider      = google.nonprod
  project       = var.nonprod_project_id
  name          = "cluster3-allow-iap-ssh"
  network       = data.google_compute_network.nonprod_cluster3.id
  direction     = "INGRESS"
  priority      = 1000
  target_tags   = ["cluster3-test"]
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLASSIC VPN: vpc-cluster2 ↔ wan1-vpc1 (1 tunnel, static routing, no HA)
# CLASSIC VPN: vpc-cluster3 ↔ wan2-vpc1 (1 tunnel, static routing, no HA)
#
# Classic VPN (google_compute_vpn_gateway) requires:
#   1. A reserved static external IP per side
#   2. Forwarding rules for ESP + UDP 500 + UDP 4500
#   3. A single VPN tunnel using peer_ip (not peer_gcp_gateway)
#   4. Static routes on both sides — no Cloud Router / BGP needed
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Static external IPs ───────────────────────────────────────────────────────

resource "google_compute_address" "wan1_cluster2_vpn_ip" {
  project = var.project_id
  name    = "wan1-cluster2-vpn-ip"
  region  = "us-central1"
}

resource "google_compute_address" "wan2_cluster3_vpn_ip" {
  project = var.project_id
  name    = "wan2-cluster3-vpn-ip"
  region  = "us-central1"
}

resource "google_compute_address" "cluster2_vpn_ip" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "cluster2-to-wan1-vpn-ip"
  region   = "us-central1"
}

resource "google_compute_address" "cluster3_vpn_ip" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "cluster3-to-wan2-vpn-ip"
  region   = "us-central1"
}

# ─── Classic VPN Gateways ──────────────────────────────────────────────────────

resource "google_compute_vpn_gateway" "wan1_to_cluster2_gw" {
  project = var.project_id
  name    = "wan1-vpn-to-cluster2-usc1"
  network = module.vpcs["wan1-vpc1"].network_self_link
  region  = "us-central1"
}

resource "google_compute_vpn_gateway" "wan2_to_cluster3_gw" {
  project = var.project_id
  name    = "wan2-vpn-to-cluster3-usc1"
  network = module.vpcs["wan2-vpc1"].network_self_link
  region  = "us-central1"
}

resource "google_compute_vpn_gateway" "nonprod_cluster2_gw" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "nonprod-cluster2-vpn-gw-usc1"
  network  = data.google_compute_network.nonprod_cluster2.id
  region   = "us-central1"
}

resource "google_compute_vpn_gateway" "nonprod_cluster3_gw" {
  provider = google.nonprod
  project  = var.nonprod_project_id
  name     = "nonprod-cluster3-vpn-gw-usc1"
  network  = data.google_compute_network.nonprod_cluster3.id
  region   = "us-central1"
}

# ─── Forwarding Rules — wan1-vpc1 side ────────────────────────────────────────

resource "google_compute_forwarding_rule" "wan1_cluster2_esp" {
  project     = var.project_id
  name        = "wan1-cluster2-vpn-esp"
  region      = "us-central1"
  ip_address  = google_compute_address.wan1_cluster2_vpn_ip.address
  ip_protocol = "ESP"
  target      = google_compute_vpn_gateway.wan1_to_cluster2_gw.id
}

resource "google_compute_forwarding_rule" "wan1_cluster2_udp500" {
  project     = var.project_id
  name        = "wan1-cluster2-vpn-udp500"
  region      = "us-central1"
  ip_address  = google_compute_address.wan1_cluster2_vpn_ip.address
  ip_protocol = "UDP"
  port_range  = "500"
  target      = google_compute_vpn_gateway.wan1_to_cluster2_gw.id
}

resource "google_compute_forwarding_rule" "wan1_cluster2_udp4500" {
  project     = var.project_id
  name        = "wan1-cluster2-vpn-udp4500"
  region      = "us-central1"
  ip_address  = google_compute_address.wan1_cluster2_vpn_ip.address
  ip_protocol = "UDP"
  port_range  = "4500"
  target      = google_compute_vpn_gateway.wan1_to_cluster2_gw.id
}

# ─── Forwarding Rules — wan2-vpc1 side ────────────────────────────────────────

resource "google_compute_forwarding_rule" "wan2_cluster3_esp" {
  project     = var.project_id
  name        = "wan2-cluster3-vpn-esp"
  region      = "us-central1"
  ip_address  = google_compute_address.wan2_cluster3_vpn_ip.address
  ip_protocol = "ESP"
  target      = google_compute_vpn_gateway.wan2_to_cluster3_gw.id
}

resource "google_compute_forwarding_rule" "wan2_cluster3_udp500" {
  project     = var.project_id
  name        = "wan2-cluster3-vpn-udp500"
  region      = "us-central1"
  ip_address  = google_compute_address.wan2_cluster3_vpn_ip.address
  ip_protocol = "UDP"
  port_range  = "500"
  target      = google_compute_vpn_gateway.wan2_to_cluster3_gw.id
}

resource "google_compute_forwarding_rule" "wan2_cluster3_udp4500" {
  project     = var.project_id
  name        = "wan2-cluster3-vpn-udp4500"
  region      = "us-central1"
  ip_address  = google_compute_address.wan2_cluster3_vpn_ip.address
  ip_protocol = "UDP"
  port_range  = "4500"
  target      = google_compute_vpn_gateway.wan2_to_cluster3_gw.id
}

# ─── Forwarding Rules — vpc-cluster2 side ─────────────────────────────────────

resource "google_compute_forwarding_rule" "cluster2_esp" {
  provider    = google.nonprod
  project     = var.nonprod_project_id
  name        = "cluster2-vpn-esp"
  region      = "us-central1"
  ip_address  = google_compute_address.cluster2_vpn_ip.address
  ip_protocol = "ESP"
  target      = google_compute_vpn_gateway.nonprod_cluster2_gw.id
}

resource "google_compute_forwarding_rule" "cluster2_udp500" {
  provider    = google.nonprod
  project     = var.nonprod_project_id
  name        = "cluster2-vpn-udp500"
  region      = "us-central1"
  ip_address  = google_compute_address.cluster2_vpn_ip.address
  ip_protocol = "UDP"
  port_range  = "500"
  target      = google_compute_vpn_gateway.nonprod_cluster2_gw.id
}

resource "google_compute_forwarding_rule" "cluster2_udp4500" {
  provider    = google.nonprod
  project     = var.nonprod_project_id
  name        = "cluster2-vpn-udp4500"
  region      = "us-central1"
  ip_address  = google_compute_address.cluster2_vpn_ip.address
  ip_protocol = "UDP"
  port_range  = "4500"
  target      = google_compute_vpn_gateway.nonprod_cluster2_gw.id
}

# ─── Forwarding Rules — vpc-cluster3 side ─────────────────────────────────────

resource "google_compute_forwarding_rule" "cluster3_esp" {
  provider    = google.nonprod
  project     = var.nonprod_project_id
  name        = "cluster3-vpn-esp"
  region      = "us-central1"
  ip_address  = google_compute_address.cluster3_vpn_ip.address
  ip_protocol = "ESP"
  target      = google_compute_vpn_gateway.nonprod_cluster3_gw.id
}

resource "google_compute_forwarding_rule" "cluster3_udp500" {
  provider    = google.nonprod
  project     = var.nonprod_project_id
  name        = "cluster3-vpn-udp500"
  region      = "us-central1"
  ip_address  = google_compute_address.cluster3_vpn_ip.address
  ip_protocol = "UDP"
  port_range  = "500"
  target      = google_compute_vpn_gateway.nonprod_cluster3_gw.id
}

resource "google_compute_forwarding_rule" "cluster3_udp4500" {
  provider    = google.nonprod
  project     = var.nonprod_project_id
  name        = "cluster3-vpn-udp4500"
  region      = "us-central1"
  ip_address  = google_compute_address.cluster3_vpn_ip.address
  ip_protocol = "UDP"
  port_range  = "4500"
  target      = google_compute_vpn_gateway.nonprod_cluster3_gw.id
}

# ─── Single Tunnel — wan1-vpc1 ↔ vpc-cluster2 ─────────────────────────────────

resource "google_compute_vpn_tunnel" "wan1_to_cluster2" {
  project            = var.project_id
  name               = "wan1-to-cluster2-tunnel"
  region             = "us-central1"
  target_vpn_gateway = google_compute_vpn_gateway.wan1_to_cluster2_gw.id
  peer_ip            = google_compute_address.cluster2_vpn_ip.address
  shared_secret      = random_password.psk_cluster2_wan1.result
  ike_version        = 2
  local_traffic_selector  = ["0.0.0.0/0"]
  remote_traffic_selector = ["0.0.0.0/0"]
  depends_on = [
    google_compute_forwarding_rule.wan1_cluster2_esp,
    google_compute_forwarding_rule.wan1_cluster2_udp500,
    google_compute_forwarding_rule.wan1_cluster2_udp4500,
  ]
}

resource "google_compute_vpn_tunnel" "nonprod_cluster2_to_wan1" {
  provider           = google.nonprod
  project            = var.nonprod_project_id
  name               = "cluster2-to-wan1-tunnel"
  region             = "us-central1"
  target_vpn_gateway = google_compute_vpn_gateway.nonprod_cluster2_gw.id
  peer_ip            = google_compute_address.wan1_cluster2_vpn_ip.address
  shared_secret      = random_password.psk_cluster2_wan1.result
  ike_version        = 2
  local_traffic_selector  = ["0.0.0.0/0"]
  remote_traffic_selector = ["0.0.0.0/0"]
  depends_on = [
    google_compute_forwarding_rule.cluster2_esp,
    google_compute_forwarding_rule.cluster2_udp500,
    google_compute_forwarding_rule.cluster2_udp4500,
  ]
}

# ─── Single Tunnel — wan2-vpc1 ↔ vpc-cluster3 ─────────────────────────────────

resource "google_compute_vpn_tunnel" "wan2_to_cluster3" {
  project            = var.project_id
  name               = "wan2-to-cluster3-tunnel"
  region             = "us-central1"
  target_vpn_gateway = google_compute_vpn_gateway.wan2_to_cluster3_gw.id
  peer_ip            = google_compute_address.cluster3_vpn_ip.address
  shared_secret      = random_password.psk_cluster3_wan2.result
  ike_version        = 2
  local_traffic_selector  = ["0.0.0.0/0"]
  remote_traffic_selector = ["0.0.0.0/0"]
  depends_on = [
    google_compute_forwarding_rule.wan2_cluster3_esp,
    google_compute_forwarding_rule.wan2_cluster3_udp500,
    google_compute_forwarding_rule.wan2_cluster3_udp4500,
  ]
}

resource "google_compute_vpn_tunnel" "nonprod_cluster3_to_wan2" {
  provider           = google.nonprod
  project            = var.nonprod_project_id
  name               = "cluster3-to-wan2-tunnel"
  region             = "us-central1"
  target_vpn_gateway = google_compute_vpn_gateway.nonprod_cluster3_gw.id
  peer_ip            = google_compute_address.wan2_cluster3_vpn_ip.address
  shared_secret      = random_password.psk_cluster3_wan2.result
  ike_version        = 2
  local_traffic_selector  = ["0.0.0.0/0"]
  remote_traffic_selector = ["0.0.0.0/0"]
  depends_on = [
    google_compute_forwarding_rule.cluster3_esp,
    google_compute_forwarding_rule.cluster3_udp500,
    google_compute_forwarding_rule.cluster3_udp4500,
  ]
}

# ─── Static Routes ────────────────────────────────────────────────────────────

# wan1-vpc1 → vpc-cluster2 supernet
resource "google_compute_route" "wan1_to_cluster2" {
  project             = var.project_id
  name                = "wan1-to-cluster2-route"
  network             = module.vpcs["wan1-vpc1"].network_self_link
  dest_range          = "10.20.0.0/16"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.wan1_to_cluster2.id
}

# wan2-vpc1 → vpc-cluster3 supernet
resource "google_compute_route" "wan2_to_cluster3" {
  project             = var.project_id
  name                = "wan2-to-cluster3-route"
  network             = module.vpcs["wan2-vpc1"].network_self_link
  dest_range          = "10.21.0.0/16"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.wan2_to_cluster3.id
}

# vpc-cluster2 → wan1-vpc1 subnets
resource "google_compute_route" "cluster2_to_wan1_s1_usc1" {
  provider            = google.nonprod
  project             = var.nonprod_project_id
  name                = "cluster2-to-wan1-s1-usc1"
  network             = data.google_compute_network.nonprod_cluster2.id
  dest_range          = "10.0.1.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.nonprod_cluster2_to_wan1.id
}

resource "google_compute_route" "cluster2_to_wan1_s2_usc1" {
  provider            = google.nonprod
  project             = var.nonprod_project_id
  name                = "cluster2-to-wan1-s2-usc1"
  network             = data.google_compute_network.nonprod_cluster2.id
  dest_range          = "10.0.2.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.nonprod_cluster2_to_wan1.id
}

resource "google_compute_route" "cluster2_to_wan1_s1_use4" {
  provider            = google.nonprod
  project             = var.nonprod_project_id
  name                = "cluster2-to-wan1-s1-use4"
  network             = data.google_compute_network.nonprod_cluster2.id
  dest_range          = "10.0.101.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.nonprod_cluster2_to_wan1.id
}

resource "google_compute_route" "cluster2_to_wan1_s2_use4" {
  provider            = google.nonprod
  project             = var.nonprod_project_id
  name                = "cluster2-to-wan1-s2-use4"
  network             = data.google_compute_network.nonprod_cluster2.id
  dest_range          = "10.0.102.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.nonprod_cluster2_to_wan1.id
}

# vpc-cluster3 → wan2-vpc1 subnets
resource "google_compute_route" "cluster3_to_wan2_s1_usc1" {
  provider            = google.nonprod
  project             = var.nonprod_project_id
  name                = "cluster3-to-wan2-s1-usc1"
  network             = data.google_compute_network.nonprod_cluster3.id
  dest_range          = "10.0.11.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.nonprod_cluster3_to_wan2.id
}

resource "google_compute_route" "cluster3_to_wan2_s2_usc1" {
  provider            = google.nonprod
  project             = var.nonprod_project_id
  name                = "cluster3-to-wan2-s2-usc1"
  network             = data.google_compute_network.nonprod_cluster3.id
  dest_range          = "10.0.12.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.nonprod_cluster3_to_wan2.id
}

resource "google_compute_route" "cluster3_to_wan2_s1_use4" {
  provider            = google.nonprod
  project             = var.nonprod_project_id
  name                = "cluster3-to-wan2-s1-use4"
  network             = data.google_compute_network.nonprod_cluster3.id
  dest_range          = "10.0.111.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.nonprod_cluster3_to_wan2.id
}

resource "google_compute_route" "cluster3_to_wan2_s2_use4" {
  provider            = google.nonprod
  project             = var.nonprod_project_id
  name                = "cluster3-to-wan2-s2-use4"
  network             = data.google_compute_network.nonprod_cluster3.id
  dest_range          = "10.0.112.0/24"
  priority            = 1000
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.nonprod_cluster3_to_wan2.id
}

# Firewall — allow ingress from cluster VPC subnets into WAN VPCs
resource "google_compute_firewall" "wan1_allow_from_cluster2" {
  project       = var.project_id
  name          = "wan1-allow-from-cluster2"
  network       = module.vpcs["wan1-vpc1"].network_self_link
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.cluster2_cidr_ranges
  allow { protocol = "all" }
}

resource "google_compute_firewall" "wan2_allow_from_cluster3" {
  project       = var.project_id
  name          = "wan2-allow-from-cluster3"
  network       = module.vpcs["wan2-vpc1"].network_self_link
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.cluster3_cidr_ranges
  allow { protocol = "all" }
}

# ─── Outputs ───────────────────────────────────────────────────────────────────

output "vpn_wan1_cluster2_gateway_ip" {
  description = "WAN1 Classic VPN gateway public IP (→ vpc-cluster2, 1 static tunnel)"
  value       = google_compute_address.wan1_cluster2_vpn_ip.address
}

output "vpn_wan2_cluster3_gateway_ip" {
  description = "WAN2 Classic VPN gateway public IP (→ vpc-cluster3, 1 static tunnel)"
  value       = google_compute_address.wan2_cluster3_vpn_ip.address
}

# ═══════════════════════════════════════════════════════════════════════════════
# AWS  —  commented out until authorized
# ═══════════════════════════════════════════════════════════════════════════════

# resource "google_compute_ha_vpn_gateway" "wan2_to_aws_gw" { ... }
# resource "google_compute_router" "wan2_aws_cr" { ... }
# resource "aws_vpc" "onprem" { ... }
# resource "aws_subnet" "onprem_a" { ... }
# resource "aws_subnet" "onprem_b" { ... }
# resource "aws_vpn_gateway" "onprem" { ... }
# resource "aws_vpn_gateway_attachment" "onprem" { ... }
# resource "aws_route_table" "onprem" { ... }
# resource "aws_vpn_gateway_route_propagation" "onprem" { ... }
# resource "aws_route_table_association" "onprem_a" { ... }
# resource "aws_route_table_association" "onprem_b" { ... }
# resource "aws_customer_gateway" "gcp_if0" { ... }
# resource "aws_customer_gateway" "gcp_if1" { ... }
# resource "aws_vpn_connection" "gcp_if0" { ... }
# resource "aws_vpn_connection" "gcp_if1" { ... }
# resource "google_compute_external_vpn_gateway" "aws" { ... }
# resource "google_compute_vpn_tunnel" "wan2_to_aws" { ... }
# resource "google_compute_router_interface" "wan2_aws_if" { ... }
# resource "google_compute_router_peer" "wan2_aws_peer" { ... }
# resource "google_compute_firewall" "wan2_allow_from_aws" { ... }

# ═══════════════════════════════════════════════════════════════════════════════
# Outputs
# ═══════════════════════════════════════════════════════════════════════════════

output "vpn_gcp_wan1_gateway_ips" {
  description = "WAN1 HA VPN gateway public IPs (→ non-prod DC, Link 1)"
  value = {
    interface_0 = google_compute_ha_vpn_gateway.wan1_to_nonprod_gw.vpn_interfaces[0].ip_address
    interface_1 = google_compute_ha_vpn_gateway.wan1_to_nonprod_gw.vpn_interfaces[1].ip_address
  }
}

output "vpn_gcp_wan2_gateway_ips" {
  description = "WAN2 HA VPN gateway public IPs (→ non-prod DC, Link 2)"
  value = {
    interface_0 = google_compute_ha_vpn_gateway.wan2_to_nonprod_gw.vpn_interfaces[0].ip_address
    interface_1 = google_compute_ha_vpn_gateway.wan2_to_nonprod_gw.vpn_interfaces[1].ip_address
  }
}

# output "vpn_aws_gw_ips" { ... }       # uncomment when AWS VPN is authorized

output "wan1_test_instance_ips" {
  description = "Internal IPs of wan1-vpc1 test instances keyed by zone shortname"
  value       = { for k, v in google_compute_instance.wan1_test : k => v.network_interface[0].network_ip }
}

output "wan2_test_instance_ips" {
  description = "Internal IPs of wan2-vpc1 test instances keyed by zone shortname"
  value       = { for k, v in google_compute_instance.wan2_test : k => v.network_interface[0].network_ip }
}
# output "vpn_aws_tunnel_addresses" { ... }
