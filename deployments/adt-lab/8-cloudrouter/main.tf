# Stage 8 — Cloud Router BGP peers (GCP side of Cisco RA-spoke adjacency).
#
# Apply order: 1-shared -> 2-fabric -> 5-appliance -> 8-cloudrouter
# Destroy order: 8-cloudrouter -> 5-appliance -> 2-fabric -> 1-shared
#
# Each Cisco C8000v peers with its region's Cloud Router on 3 VPCs:
#   WAN1 (wan1-vpc1)        — Cisco Gi2, CR cr-wan1-adt1-{region}
#   WAN2 (wan2-vpc1)        — Cisco Gi3, CR cr-wan2-adt1-{region}
#   LAN  (lan-transit-vpc1) — Cisco Gi4, CR cr-lan-transit-adt1-{region}
#
# Per-VPC: 2 google_compute_router_peer resources per Cisco instance
# (one per Cloud Router NIC). The Cloud Router names and interface names
# come from 2-fabric; the instance self_links come from data lookups into
# the running 5-appliance state.

locals {
  project_id = "rteller-demo-svc-e265-aaac"
  cisco_asn  = 65100

  # Maps zone → region shorthand used in subnet and cloud-router names.
  region_short = {
    "us-central1-a" = "usc1"
    "us-central1-b" = "usc1"
    "us-east4-a"    = "use4"
    "us-east4-b"    = "use4"
    "us-west2-a"    = "usw2"
    "us-west2-b"    = "usw2"
  }

  cisco_instances = {
    "adt-lab-cisco-usc1-a" = {
      zone      = "us-central1-a"
      wan1_ip   = "10.0.1.3"
      wan2_ip   = "10.0.11.3"
      lan_ip    = "172.16.1.3"
      wan1_cr   = "cr-wan1-adt1-usc1"
      wan2_cr   = "cr-wan2-adt1-usc1"
      lan_cr    = "cr-lan-transit-adt1-usc1"
      wan1_nic0 = "int-wan1-adt1-usc1-0"
      wan1_nic1 = "int-wan1-adt1-usc1-1"
      wan2_nic0 = "int-wan2-adt1-usc1-0"
      wan2_nic1 = "int-wan2-adt1-usc1-1"
      lan_nic0  = "int-lan-transit-adt1-usc1-0"
      lan_nic1  = "int-lan-transit-adt1-usc1-1"
    }
    "adt-lab-cisco-usc1-b" = {
      zone      = "us-central1-b"
      wan1_ip   = "10.0.1.4"
      wan2_ip   = "10.0.11.4"
      lan_ip    = "172.16.1.4"
      wan1_cr   = "cr-wan1-adt1-usc1"
      wan2_cr   = "cr-wan2-adt1-usc1"
      lan_cr    = "cr-lan-transit-adt1-usc1"
      wan1_nic0 = "int-wan1-adt1-usc1-0"
      wan1_nic1 = "int-wan1-adt1-usc1-1"
      wan2_nic0 = "int-wan2-adt1-usc1-0"
      wan2_nic1 = "int-wan2-adt1-usc1-1"
      lan_nic0  = "int-lan-transit-adt1-usc1-0"
      lan_nic1  = "int-lan-transit-adt1-usc1-1"
    }
    "adt-lab-cisco-use4-a" = {
      zone      = "us-east4-a"
      wan1_ip   = "10.0.101.3"
      wan2_ip   = "10.0.111.3"
      lan_ip    = "172.16.101.3"
      wan1_cr   = "cr-wan1-adt1-use4"
      wan2_cr   = "cr-wan2-adt1-use4"
      lan_cr    = "cr-lan-transit-adt1-use4"
      wan1_nic0 = "int-wan1-adt1-use4-0"
      wan1_nic1 = "int-wan1-adt1-use4-1"
      wan2_nic0 = "int-wan2-adt1-use4-0"
      wan2_nic1 = "int-wan2-adt1-use4-1"
      lan_nic0  = "int-lan-transit-adt1-use4-0"
      lan_nic1  = "int-lan-transit-adt1-use4-1"
    }
    "adt-lab-cisco-use4-b" = {
      zone      = "us-east4-b"
      wan1_ip   = "10.0.101.4"
      wan2_ip   = "10.0.111.4"
      lan_ip    = "172.16.101.4"
      wan1_cr   = "cr-wan1-adt1-use4"
      wan2_cr   = "cr-wan2-adt1-use4"
      lan_cr    = "cr-lan-transit-adt1-use4"
      wan1_nic0 = "int-wan1-adt1-use4-0"
      wan1_nic1 = "int-wan1-adt1-use4-1"
      wan2_nic0 = "int-wan2-adt1-use4-0"
      wan2_nic1 = "int-wan2-adt1-use4-1"
      lan_nic0  = "int-lan-transit-adt1-use4-0"
      lan_nic1  = "int-lan-transit-adt1-use4-1"
    }
    "adt-lab-cisco-usw2-a" = {
      zone      = "us-west2-a"
      wan1_ip   = "10.0.201.3"
      wan2_ip   = "10.0.211.3"
      lan_ip    = "172.16.201.3"
      wan1_cr   = "cr-wan1-adt1-usw2"
      wan2_cr   = "cr-wan2-adt1-usw2"
      lan_cr    = "cr-lan-transit-adt1-usw2"
      wan1_nic0 = "int-wan1-adt1-usw2-0"
      wan1_nic1 = "int-wan1-adt1-usw2-1"
      wan2_nic0 = "int-wan2-adt1-usw2-0"
      wan2_nic1 = "int-wan2-adt1-usw2-1"
      lan_nic0  = "int-lan-transit-adt1-usw2-0"
      lan_nic1  = "int-lan-transit-adt1-usw2-1"
    }
    "adt-lab-cisco-usw2-b" = {
      zone      = "us-west2-b"
      wan1_ip   = "10.0.201.4"
      wan2_ip   = "10.0.211.4"
      lan_ip    = "172.16.201.4"
      wan1_cr   = "cr-wan1-adt1-usw2"
      wan2_cr   = "cr-wan2-adt1-usw2"
      lan_cr    = "cr-lan-transit-adt1-usw2"
      wan1_nic0 = "int-wan1-adt1-usw2-0"
      wan1_nic1 = "int-wan1-adt1-usw2-1"
      wan2_nic0 = "int-wan2-adt1-usw2-0"
      wan2_nic1 = "int-wan2-adt1-usw2-1"
      lan_nic0  = "int-lan-transit-adt1-usw2-0"
      lan_nic1  = "int-lan-transit-adt1-usw2-1"
    }
  }
}

# Look up each Cisco instance to obtain its self_link.
# The instances are created in 5-appliance; this stage depends on them existing.
data "google_compute_instance" "cisco" {
  for_each = local.cisco_instances
  project  = local.project_id
  name     = each.key
  zone     = each.value.zone
}

# ── WAN1 BGP peers (Cisco Gi2 ↔ cr-wan1-adt1-{region}) ──────────────────────

module "wan1_bgp" {
  for_each   = local.cisco_instances
  source     = "../../../modules/gcp_cloud_router_bgp_peering"
  project_id = local.project_id

  bgp_peering = {
    instance_address   = each.value.wan1_ip
    instance_asn       = local.cisco_asn
    instance_name      = each.key
    instance_self_link = data.google_compute_instance.cisco[each.key].self_link
    instance_zone      = each.value.zone
    subnetwork_name    = "wan1-s1-${local.region_short[each.value.zone]}"
    cloud_router_name  = each.value.wan1_cr

    peers = [
      { cloud_router_nic_name = each.value.wan1_nic0 },
      { cloud_router_nic_name = each.value.wan1_nic1 },
    ]
  }
}

# ── WAN2 BGP peers (Cisco Gi3 ↔ cr-wan2-adt1-{region}) ──────────────────────

module "wan2_bgp" {
  for_each   = local.cisco_instances
  source     = "../../../modules/gcp_cloud_router_bgp_peering"
  project_id = local.project_id

  bgp_peering = {
    instance_address   = each.value.wan2_ip
    instance_asn       = local.cisco_asn
    instance_name      = each.key
    instance_self_link = data.google_compute_instance.cisco[each.key].self_link
    instance_zone      = each.value.zone
    subnetwork_name    = "wan2-s1-${local.region_short[each.value.zone]}"
    cloud_router_name  = each.value.wan2_cr

    peers = [
      { cloud_router_nic_name = each.value.wan2_nic0 },
      { cloud_router_nic_name = each.value.wan2_nic1 },
    ]
  }
}

# ── LAN BGP peers (Cisco Gi4 ↔ cr-lan-transit-adt1-{region}) ────────────────

module "lan_bgp" {
  for_each   = local.cisco_instances
  source     = "../../../modules/gcp_cloud_router_bgp_peering"
  project_id = local.project_id

  bgp_peering = {
    instance_address   = each.value.lan_ip
    instance_asn       = local.cisco_asn
    instance_name      = each.key
    instance_self_link = data.google_compute_instance.cisco[each.key].self_link
    instance_zone      = each.value.zone
    subnetwork_name    = "lan-transit-vpc1-s2-${local.region_short[each.value.zone]}"
    cloud_router_name  = each.value.lan_cr

    peers = [
      { cloud_router_nic_name = each.value.lan_nic0 },
      { cloud_router_nic_name = each.value.lan_nic1 },
    ]
  }
}
