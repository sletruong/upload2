# Stage 5-appliance — PALO ALTO ONLY.
#
# Everything not related to the Palo Alto VM-Series fleet is commented out:
# Cisco C8000v instances, NCC appliance spokes, NCC VPC spokes, Cloud Routers,
# and the routing test VMs. Uncomment a block to bring that family back.

project_id = "rteller-demo-svc-e265-aaac"

# ─── Regions ───────────────────────────────────────────────────────────────────
# short_name is the region token used in BOTH instance and subnet names:
#   instance : adtgcp-{short_name}-{zone}-fw-01   e.g. adtgcp-cent1-a-fw-01
#   subnet   : adtgcp-us-{short_name}-...         e.g. adtgcp-us-cent1-pa-mgmt
#
# Palo Alto fleet — 7 firewalls:
#   us-central1  zones a, b, c  ->  adtgcp-cent1-a/b/c-fw-01
#   us-east4     zones a, b     ->  adtgcp-east4-a/b-fw-01
#   us-west2     zones a, b     ->  adtgcp-west2-a/b-fw-01
#
# intercept_zones is the SUPERSET of zones needing an NSI intercept deployment.
# A zone with no intercept deployment fails OPEN (workloads there are not
# inspected), so east4-c and west2-c keep a deployment backed by the in-region
# regional backend service even though no firewall is pinned in those zones.
regions = {
  "us-central1" = {
    short_name      = "cent1"
    zone_suffix     = "a"
    zones           = ["a", "b", "c"]
    intercept_zones = ["a", "b", "c"]
  }
  "us-east4" = {
    short_name      = "east4"
    zone_suffix     = "a"
    zones           = ["a", "b"]
    intercept_zones = ["a", "b", "c"]
  }
  "us-west2" = {
    short_name      = "west2"
    zone_suffix     = "a"
    zones           = ["a", "b"]
    intercept_zones = ["a", "b", "c"]
  }
}

# ─── Palo Alto Firewall ─────────────────────────────────────────────────────────
# Instance name = "{palo_name}-{short_name}-{zone}-{palo_name_suffix}"
palo_name        = "adtgcp"
palo_name_suffix = "fw-01"

palo_ssh_key_path = "../.ssh-palo.pub"

# ⚠ NIC BUDGET — n4-standard-4 (4 vCPU) CANNOT HOLD THE 6 NICs DEFINED BELOW.
# The interface budget is ~1 per vCPU: 4 interfaces TOTAL of any type at
# 4 vCPU, platform maximum 8. 6 NICs needs >= 6 vCPU, so n4-standard-8.
# Left at 4 vCPU per instruction — update manually before apply.
palo_machine_type     = "n4-standard-4"
palo_min_cpu_platform = "Intel Emerald Rapids"
palo_image            = "vmseries-flex-bundle3-1217"

palo_tags = ["adt-lab-palo", "allow-ssh"]

palo_labels = {
  environment = "prd"
  appliance   = "palo"
  team        = "adt"
}

# Bootstrap metadata for GENEVE/NSI intercept mode.
# plugin-op-commands uses COLON separator — "geneve-inspect:enable" is correct.
# "geneve-inspect=enable" is silently inert (documented GCP NSI gotcha).
palo_metadata = {
  "plugin-op-commands"          = "geneve-inspect:enable"
  "dhcp-send-hostname"          = "yes"
  "dhcp-send-client-id"         = "yes"
  "dhcp-accept-server-hostname" = "yes"
  "dhcp-accept-server-domain"   = "yes"
  "enable-oslogin"              = "FALSE"
}

palo_metadata_startup_script = null

# 6 NICs. List position IS the GCP NIC index — order is load-bearing and
# fixed at instance creation.
#
# The token "{region}" inside subnet is replaced with the region short_name,
# so one entry covers all three regions.
#
#   NIC 0  adtgcp-nsi-pa-mgmt             management
#   NIC 1  adtgcp-nsi-pa-producer-01      NSI producer 1
#   NIC 2  adtgcp-nsi-pa-producer-02      NSI producer 2
#   NIC 3  adtgcp-nsi-pa-producer-03      NSI producer 3
#   NIC 4  adtgcp-nsi-pa-producer-04      NSI producer 4
#   NIC 5  adtgcp-nsi-pa-inet-egress-01   internet egress
#
# Each NIC attaches a DIFFERENT VPC — the GA law. Same-VPC multi-NIC is Preview.
palo_network_interfaces = [
  {
    # NIC 0 — Management
    vpc    = "adtgcp-nsi-pa-mgmt"
    subnet = "adtgcp-us-{region}-pa-mgmt"
  },
  {
    # NIC 1 — NSI producer 01
    vpc    = "adtgcp-nsi-pa-producer-01"
    subnet = "adtgcp-us-{region}-nsi-pa-01"
  },
  {
    # NIC 2 — NSI producer 02
    vpc    = "adtgcp-nsi-pa-producer-02"
    subnet = "adtgcp-us-{region}-nsi-pa-02"
  },
  {
    # NIC 3 — NSI producer 03
    vpc    = "adtgcp-nsi-pa-producer-03"
    subnet = "adtgcp-us-{region}-nsi-pa-03"
  },
  {
    # NIC 4 — NSI producer 04
    vpc    = "adtgcp-nsi-pa-producer-04"
    subnet = "adtgcp-us-{region}-nsi-pa-04"
  },
  {
    # NIC 5 — Internet egress
    vpc    = "adtgcp-nsi-pa-inet-egress-01"
    subnet = "adtgcp-us-{region}-nsi-pa-inet-egress-01"
  },
]

# ─── NSI (Network Security Integration) ─────────────────────────────────────────
# Producer VPCs rewired to the adtgcp scheme. One fleet per producer VPC:
#   EWTI -> adtgcp-nsi-pa-producer-01 (Palo NIC 1)
#   NSTI -> adtgcp-nsi-pa-producer-02 (Palo NIC 2)
# producer-03 and producer-04 are attached to the firewalls but have no
# intercept fleet yet — add further module blocks in main.tf when needed.
nsi_ewti_producer_vpc    = "adtgcp-nsi-pa-producer-01"
nsi_ewti_producer_subnet = "adtgcp-us-{region}-nsi-pa-01"

nsi_nsti_producer_vpc    = "adtgcp-nsi-pa-producer-02"
nsi_nsti_producer_subnet = "adtgcp-us-{region}-nsi-pa-02"

nsi_ewti_enabled = true
nsi_nsti_enabled = true

# Consumer VPCs are NOT consumed by this stage — stage 6-policy owns the GNFP
# associations and intercept rules. Left empty because the previous lists
# (wan1-vpc1, wan2-vpc1, lan-transit-vpc1 / lan-workload-vpc1, lan-workload-vpc2)
# belong to the Cisco-era fabric and have no adtgcp equivalent yet.
# Populate once 2-fabric defines the consumer VPCs under the new scheme.
nsi_ewti_consumer_vpcs = []
nsi_nsti_consumer_vpcs = []

# ═══════════════════════════════════════════════════════════════════════════════
# COMMENTED OUT — NOT PALO ALTO
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Cisco Router ──────────────────────────────────────────────────────────────
# cisco_name         = "adt-lab-cisco"
# cisco_username     = "admin"
# cisco_ssh_key_path = "../.ssh-cisco.pub"
# # Note: us-west2 may require n2-standard-4 / Intel Cascade Lake instead of n4.
# # If apply fails in us-west2, override machine type for that region manually.
# cisco_machine_type     = "n4-standard-4"
# cisco_min_cpu_platform = "Intel Emerald Rapids"
# cisco_image            = "cisco-c8k-17-16-01a-byol"
#
# cisco_tags = ["adt-lab-cisco", "allow-ssh"]
#
# cisco_labels = {
#   environment = "lab"
#   appliance   = "cisco"
#   team        = "adt"
# }
#
# cisco_bgp_asn = 65100
#
# # NIC 0 = Gi1 (management), NIC 1 = Gi2 (WAN1), NIC 2 = Gi3 (WAN2), NIC 3 = Gi4 (LAN).
# # NOTE: these subnet names use the OLD suffix convention ({subnet}-{short_name})
# # and the OLD short_names (usc1/use4/usw2). Re-enabling Cisco means revisiting
# # both, because `regions` above now carries cent1/east4/west2.
# cisco_network_interfaces = [
#   {
#     # NIC 0 — Management (GigabitEthernet1)
#     vpc    = "lan-mgmt-vpc"
#     subnet = "lan-mgmt-vpc-s1"
#   },
#   {
#     # NIC 1 — WAN1 (GigabitEthernet2)
#     vpc    = "wan1-vpc1"
#     subnet = "wan1-s1"
#   },
#   {
#     # NIC 2 — WAN2 (GigabitEthernet3)
#     vpc    = "wan2-vpc1"
#     subnet = "wan2-s1"
#   },
#   {
#     # NIC 3 — LAN / Transit (GigabitEthernet4)
#     vpc    = "lan-transit-vpc1"
#     subnet = "lan-transit-vpc1-s2"
#   },
# ]

# ─── NCC Appliance Spokes ──────────────────────────────────────────────────────
# One spoke per VPC per region (groups both zone-a and zone-b instances).
# ncc_appliance_spokes = {
#   "cisco-spoke-wan1-usc1" = {
#     hub_key   = "wan1-ncc-hub"
#     appliance = "cisco"
#     region    = "us-central1"
#     nic_index = 1
#   }
#   "cisco-spoke-wan2-usc1" = {
#     hub_key   = "wan2-ncc-hub"
#     appliance = "cisco"
#     region    = "us-central1"
#     nic_index = 2
#   }
#   "cisco-spoke-lan-usc1" = {
#     hub_key   = "lan-ncc-hub"
#     appliance = "cisco"
#     region    = "us-central1"
#     nic_index = 3
#   }
#   "cisco-spoke-wan1-use4" = {
#     hub_key   = "wan1-ncc-hub"
#     appliance = "cisco"
#     region    = "us-east4"
#     nic_index = 1
#   }
#   "cisco-spoke-wan2-use4" = {
#     hub_key   = "wan2-ncc-hub"
#     appliance = "cisco"
#     region    = "us-east4"
#     nic_index = 2
#   }
#   "cisco-spoke-lan-use4" = {
#     hub_key   = "lan-ncc-hub"
#     appliance = "cisco"
#     region    = "us-east4"
#     nic_index = 3
#   }
#   "cisco-spoke-wan1-usw2" = {
#     hub_key   = "wan1-ncc-hub"
#     appliance = "cisco"
#     region    = "us-west2"
#     nic_index = 1
#   }
#   "cisco-spoke-wan2-usw2" = {
#     hub_key   = "wan2-ncc-hub"
#     appliance = "cisco"
#     region    = "us-west2"
#     nic_index = 2
#   }
#   "cisco-spoke-lan-usw2" = {
#     hub_key   = "lan-ncc-hub"
#     appliance = "cisco"
#     region    = "us-west2"
#     nic_index = 3
#   }
# }

# ─── NCC VPC Spokes ────────────────────────────────────────────────────────────
# ncc_vpc_spokes = {
#   "wan1-vpc1-spoke" = {
#     hub_key      = "wan1-ncc-hub"
#     network_name = "wan1-vpc1"
#   }
#   "wan2-vpc1-spoke" = {
#     hub_key      = "wan2-ncc-hub"
#     network_name = "wan2-vpc1"
#   }
#   "lan-mgmt-vpc-spoke" = {
#     hub_key      = "lan-ncc-hub"
#     network_name = "lan-mgmt-vpc"
#   }
#   "lan-workload-vpc1-spoke" = {
#     hub_key      = "lan-ncc-hub"
#     network_name = "lan-workload-vpc1"
#   }
# }

# ─── Cloud Routers ─────────────────────────────────────────────────────────────
# Cloud Routers terminate NCC hub interfaces in each VPC.
# BGP peers (Cisco router <-> Cloud Router) are wired in 8-cloudrouter.
# cloud_routers = {
#
#   # -- lan-transit-vpc1 (Cisco NIC 3, Gi4) ------------------------------------
#   "lan-transit-vpc1" = {
#     "lan-transit-vpc1-cloudrouter-1-usc1" = {
#       region = "us-central1"
#       bgp_spoke = {
#         asn            = 65033
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/lan-transit-vpc1-s2-usc1"
#           ip_address = "172.16.1.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/lan-transit-vpc1-s2-usc1"
#           ip_address          = "172.16.1.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#     "lan-transit-vpc1-cloudrouter-1-use4" = {
#       region = "us-east4"
#       bgp_spoke = {
#         asn            = 65034
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/lan-transit-vpc1-s2-use4"
#           ip_address = "172.16.101.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/lan-transit-vpc1-s2-use4"
#           ip_address          = "172.16.101.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#     "lan-transit-vpc1-cloudrouter-1-usw2" = {
#       region = "us-west2"
#       bgp_spoke = {
#         asn            = 65039
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-west2/subnetworks/lan-transit-vpc1-s2-usw2"
#           ip_address = "172.16.201.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-west2/subnetworks/lan-transit-vpc1-s2-usw2"
#           ip_address          = "172.16.201.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#   }
#
#   # -- wan1-vpc1 (Cisco NIC 1, Gi2) -------------------------------------------
#   "wan1-vpc1" = {
#     "wan1-vpc1-cloudrouter-1-usc1" = {
#       region = "us-central1"
#       bgp_spoke = {
#         asn            = 65035
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/wan1-s1-usc1"
#           ip_address = "10.0.1.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/wan1-s1-usc1"
#           ip_address          = "10.0.1.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#     "wan1-vpc1-cloudrouter-1-use4" = {
#       region = "us-east4"
#       bgp_spoke = {
#         asn            = 65036
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/wan1-s1-use4"
#           ip_address = "10.0.101.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/wan1-s1-use4"
#           ip_address          = "10.0.101.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#     "wan1-vpc1-cloudrouter-1-usw2" = {
#       region = "us-west2"
#       bgp_spoke = {
#         asn            = 65040
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-west2/subnetworks/wan1-s1-usw2"
#           ip_address = "10.0.201.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-west2/subnetworks/wan1-s1-usw2"
#           ip_address          = "10.0.201.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#   }
#
#   # -- wan2-vpc1 (Cisco NIC 2, Gi3) -------------------------------------------
#   "wan2-vpc1" = {
#     "wan2-vpc1-cloudrouter-1-usc1" = {
#       region = "us-central1"
#       bgp_spoke = {
#         asn            = 65037
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/wan2-s1-usc1"
#           ip_address = "10.0.11.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/wan2-s1-usc1"
#           ip_address          = "10.0.11.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#     "wan2-vpc1-cloudrouter-1-use4" = {
#       region = "us-east4"
#       bgp_spoke = {
#         asn            = 65038
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/wan2-s1-use4"
#           ip_address = "10.0.111.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/wan2-s1-use4"
#           ip_address          = "10.0.111.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#     "wan2-vpc1-cloudrouter-1-usw2" = {
#       region = "us-west2"
#       bgp_spoke = {
#         asn            = 65041
#         advertise_mode = "DEFAULT"
#       }
#       ncc_interfaces = {
#         "0" = {
#           subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-west2/subnetworks/wan2-s1-usw2"
#           ip_address = "10.0.211.5"
#         }
#         "1" = {
#           subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-west2/subnetworks/wan2-s1-usw2"
#           ip_address          = "10.0.211.6"
#           redundant_interface = "0"
#         }
#       }
#     }
#   }
# }

# ─── Test VMs ───────────────────────────────────────────────────────────────────
# test_vms = {
#   "test-vm-wan1-usc1" = {
#     vpc    = "wan1-vpc1"
#     subnet = "wan1-s2-usc1"
#     region = "us-central1"
#     zone   = "us-central1-a"
#   }
#   "test-vm-wan2-usc1" = {
#     vpc    = "wan2-vpc1"
#     subnet = "wan2-s2-usc1"
#     region = "us-central1"
#     zone   = "us-central1-a"
#   }
#   "test-vm-lan-usc1" = {
#     vpc    = "lan-workload-vpc1"
#     subnet = "lan-workload-vpc1-s1-usc1"
#     region = "us-central1"
#     zone   = "us-central1-a"
#   }
# }
