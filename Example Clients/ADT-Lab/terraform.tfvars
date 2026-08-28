project_id = "rteller-demo-svc-e265-aaac"

regions = {
  "us-central1" = {
    short_name      = "usc1"
    zone_suffix     = "a"
    zones           = ["a", "b"]          # Palo Alto + Cisco instances
    intercept_zones = ["a", "b", "c"]     # NSI deployments — add zone c so workloads there don't fail open
  }
  "us-east4" = {
    short_name      = "use4"
    zone_suffix     = "a"
    zones           = ["a", "b"]
    intercept_zones = ["a", "b", "c"]
  }
}

# ─── Cisco Router ──────────────────────────────────────────────────────────────
cisco_name         = "adt-lab-cisco"
cisco_username     = "admin"
cisco_ssh_key_path = "./.ssh-cisco.pub"
cisco_machine_type     = "n4-standard-4"
cisco_min_cpu_platform = "Intel Emerald Rapids"
cisco_image            = "cisco-c8k-17-16-01a-byol" # BYOL C8000v image

cisco_tags = ["adt-lab-cisco", "allow-ssh"]

cisco_labels = {
  environment = "lab"
  appliance   = "cisco"
  team        = "adt"
}

cisco_bgp_asn = 65100 # BGP ASN configured on the Cisco C8K — update to match router config

# NIC index = GigabitEthernet interface order (NIC 0 = Gi1, NIC 1 = Gi2, …).
cisco_network_interfaces = [
  {
    # NIC 0 — Management (GigabitEthernet1)
    vpc    = "lan-mgmt-vpc"
    subnet = "lan-mgmt-vpc-s1"
  },
  {
    # NIC 1 — WAN1 (GigabitEthernet2)
    vpc    = "wan1-vpc1"
    subnet = "wan1-s1"
  },
  {
    # NIC 2 — WAN2 (GigabitEthernet3)
    vpc    = "wan2-vpc1"
    subnet = "wan2-s1"
  },
  {
    # NIC 3 — LAN / Transit (GigabitEthernet4) → lan-transit-vpc1 / s2 (172.16.x)
    vpc    = "lan-transit-vpc1"
    subnet = "lan-transit-vpc1-s2"
  },
]

# ─── Palo Alto Firewall ─────────────────────────────────────────────────────────
palo_name         = "adt-lab-palo"
palo_ssh_key_path = "./.ssh-palo.pub"
palo_machine_type     = "n4-standard-4"
palo_min_cpu_platform = "Intel Emerald Rapids"
palo_image        = "vmseries-flex-bundle3-1217" # BYOL VM-Series
# palo_image        = "vmseries-flex-byol-1217" #Latest BYOL VM-Series


# palo_ssh_keys = "ssh-rsa AAAAB3NzaC1yc2E... user@example.com"

palo_tags = ["adt-lab-palo", "allow-ssh"]

palo_labels = {
  environment = "lab"
  appliance   = "palo"
  team        = "adt"
}

# Bootstrap metadata for GENEVE/NSI intercept mode.
# plugin-op-commands uses a COLON separator — "geneve-inspect:enable" is correct.
# "geneve-inspect=enable" is silently inert (documented GCP NSI gotcha).
# mgmt-interface-swap is intentionally omitted: nic0 is already management.
# These are first-boot-only; changing them requires destroy + recreate.
palo_metadata = {
  "plugin-op-commands"          = "geneve-inspect:enable"
  "dhcp-send-hostname"          = "yes"
  "dhcp-send-client-id"         = "yes"
  "dhcp-accept-server-hostname" = "yes"
  "dhcp-accept-server-domain"   = "yes"
  "enable-oslogin"              = "FALSE"
}

palo_metadata_startup_script = null

# 3 NICs: NIC 0 = mgmt, NIC 1 = palo-producer-vpc1, NIC 2 = palo-producer-vpc2
palo_network_interfaces = [
  {
    # NIC 0 — Management
    vpc    = "lan-mgmt-vpc"
    subnet = "lan-mgmt-vpc-s1"
  },
  {
    # NIC 1 — Data plane (palo-producer-vpc1)
    vpc    = "palo-producer-vpc1"
    subnet = "palo-producer-vpc1-s1"
  },
  {
    # NIC 2 — Data plane (palo-producer-vpc2)
    vpc    = "palo-producer-vpc2"
    subnet = "palo-producer-vpc2-s1"
  },
]

# ─── NCC Hubs ──────────────────────────────────────────────────────────────────
ncc_hubs = {
  "wan1-ncc-hub" = { ncc_hub_name = "wan1-ncc-hub" }
  "wan2-ncc-hub" = { ncc_hub_name = "wan2-ncc-hub" }
  "lan-ncc-hub" = { ncc_hub_name = "lan-ncc-hub" }
}

# ─── VPCs ──────────────────────────────────────────────────────────────────────
vpcs = {
  "wan1-vpc1"          = {}
  "wan2-vpc1"          = {}
  "lan-transit-vpc1"  = {}
  "lan-workload-vpc1" = {}
  "lan-workload-vpc2" = {}
  "lan-mgmt-vpc"       = { network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL" }
  "palo-producer-vpc1" = { mtu = 8896, network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL" }
  "palo-producer-vpc2" = { mtu = 8896, network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL" }
}

# ─── Subnets ───────────────────────────────────────────────────────────────────
vpc_subnets = {
  "wan1-vpc1" = {
    "wan1-s1-usc1" = { cidr = "10.0.1.0/24",   region = "us-central1" }
    "wan1-s2-usc1" = { cidr = "10.0.2.0/24",   region = "us-central1" }
    "wan1-s1-use4" = { cidr = "10.0.101.0/24", region = "us-east4" }
    "wan1-s2-use4" = { cidr = "10.0.102.0/24", region = "us-east4" }
  }
  "wan2-vpc1" = {
    "wan2-s1-usc1" = { cidr = "10.0.11.0/24",  region = "us-central1" }
    "wan2-s2-usc1" = { cidr = "10.0.12.0/24",  region = "us-central1" }
    "wan2-s1-use4" = { cidr = "10.0.111.0/24", region = "us-east4" }
    "wan2-s2-use4" = { cidr = "10.0.112.0/24", region = "us-east4" }
  }
  "lan-transit-vpc1" = {
   "lan-transit-vpc1-s2-usc1" = { cidr = "172.16.1.0/24",   region = "us-central1" }
    "lan-transit-vpc1-s2-use4" = { cidr = "172.16.101.0/24", region = "us-east4" }
  }
  "lan-workload-vpc1" = {
    "lan-workload-vpc1-s1-usc1" = { cidr = "192.168.1.0/24",   region = "us-central1" }
    "lan-workload-vpc1-s2-usc1" = { cidr = "192.168.2.0/24",   region = "us-central1" }
    "lan-workload-vpc1-s1-use4" = { cidr = "192.168.101.0/24", region = "us-east4" }
    "lan-workload-vpc1-s2-use4" = { cidr = "192.168.102.0/24", region = "us-east4" }
  }
  "lan-workload-vpc2" = {
    "lan-workload-vpc2-s1-usc1" = { cidr = "192.168.11.0/24",  region = "us-central1" }
    "lan-workload-vpc2-s2-usc1" = { cidr = "192.168.12.0/24",  region = "us-central1" }
    "lan-workload-vpc2-s1-use4" = { cidr = "192.168.111.0/24", region = "us-east4" }
    "lan-workload-vpc2-s2-use4" = { cidr = "192.168.112.0/24", region = "us-east4" }
  }
  "lan-mgmt-vpc" = {
    "lan-mgmt-vpc-s1-usc1" = { cidr = "192.168.21.0/24",  region = "us-central1" }
    "lan-mgmt-vpc-s1-use4" = { cidr = "192.168.121.0/24", region = "us-east4" }
  }
  "palo-producer-vpc1" = {
    "palo-producer-vpc1-s1-usc1" = { cidr = "192.168.31.0/24",  region = "us-central1" }
    "palo-producer-vpc1-s1-use4" = { cidr = "192.168.131.0/24", region = "us-east4" }
  }
  "palo-producer-vpc2" = {
    "palo-producer-vpc2-s1-usc1" = { cidr = "192.168.41.0/24",  region = "us-central1" }
    "palo-producer-vpc2-s1-use4" = { cidr = "192.168.141.0/24", region = "us-east4" }
  }
}

# ─── NCC Appliance Spokes ──────────────────────────────────────────────────────
ncc_appliance_spokes = {
  "cisco-spoke-wan1-usc1" = {
    hub_key   = "wan1-ncc-hub"
    appliance = "cisco"
    region    = "us-central1"
    nic_index = 1 # WAN1 (GigabitEthernet2) → wan1-vpc1 / wan1-s1-usc1
  }
  "cisco-spoke-wan2-usc1" = {
    hub_key   = "wan2-ncc-hub"
    appliance = "cisco"
    region    = "us-central1"
    nic_index = 2 # WAN2 (GigabitEthernet3) → wan2-vpc1 / wan2-s1-usc1
  }
  "cisco-spoke-lan-usc1" = {
    hub_key   = "lan-ncc-hub"
    appliance = "cisco"
    region    = "us-central1"
    nic_index = 3 # LAN (GigabitEthernet4) → lan-transit-vpc1 / lan-transit-vpc1-s2-usc1
  }
  "cisco-spoke-wan1-use4" = {
    hub_key   = "wan1-ncc-hub"
    appliance = "cisco"
    region    = "us-east4"
    nic_index = 1 # WAN1 (GigabitEthernet2) → wan1-vpc1 / wan1-s1-use4
  }
  "cisco-spoke-wan2-use4" = {
    hub_key   = "wan2-ncc-hub"
    appliance = "cisco"
    region    = "us-east4"
    nic_index = 2 # WAN2 (GigabitEthernet3) → wan2-vpc1 / wan2-s1-use4
  }
  "cisco-spoke-lan-use4" = {
    hub_key   = "lan-ncc-hub"
    appliance = "cisco"
    region    = "us-east4"
    nic_index = 3 # LAN (GigabitEthernet4) → lan-transit-vpc1 / lan-transit-vpc1-s2-use4
  }
}

# ─── NCC VPC Spokes ────────────────────────────────────────────────────────────
ncc_vpc_spokes = {
  "wan1-vpc1-spoke" = {
    hub_key      = "wan1-ncc-hub"
    network_name = "wan1-vpc1"
  }
  "wan2-vpc1-spoke" = {
    hub_key      = "wan2-ncc-hub"
    network_name = "wan2-vpc1"
  }
  "lan-mgmt-vpc-spoke" = {
    hub_key      = "lan-ncc-hub"
    network_name = "lan-mgmt-vpc"
  }
  "lan-workload-vpc1-spoke" = {
    hub_key      = "lan-ncc-hub"
    network_name = "lan-workload-vpc1"
  }
}

# ─── Cloud Routers ─────────────────────────────────────────────────────────────
# Outer key = VPC network name. Each VPC gets its own Cloud Router module call.
cloud_routers = {

  # ── lan-transit-vpc1 (LAN / Cisco NIC 3) ─────────────────────────────────────
  "lan-transit-vpc1" = {
    "lan-transit-vpc1-cloudrouter-1-usc1" = {
      region = "us-central1"
      bgp_spoke = {
        asn            = 65033
        advertise_mode = "DEFAULT"
      }
      ncc_interfaces = {
        "0" = {
          subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/lan-transit-vpc1-s2-usc1"
          ip_address = "172.16.1.5"
        }
        "1" = {
          subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/lan-transit-vpc1-s2-usc1"
          ip_address          = "172.16.1.6"
          redundant_interface = "0"
        }
      }
    }
    "lan-transit-vpc1-cloudrouter-1-use4" = {
      region = "us-east4"
      bgp_spoke = {
        asn            = 65034
        advertise_mode = "DEFAULT"
      }
      ncc_interfaces = {
        "0" = {
          subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/lan-transit-vpc1-s2-use4"
          ip_address = "172.16.101.5"
        }
        "1" = {
          subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/lan-transit-vpc1-s2-use4"
          ip_address          = "172.16.101.6"
          redundant_interface = "0"
        }
      }
    }
  }

  # ── wan1-vpc1 (WAN1 / Cisco NIC 1) ───────────────────────────────────────────
  "wan1-vpc1" = {
    "wan1-vpc1-cloudrouter-1-usc1" = {
      region = "us-central1"
      bgp_spoke = {
        asn            = 65035
        advertise_mode = "DEFAULT"
      }
      ncc_interfaces = {
        "0" = {
          subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/wan1-s1-usc1"
          ip_address = "10.0.1.5"
        }
        "1" = {
          subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/wan1-s1-usc1"
          ip_address          = "10.0.1.6"
          redundant_interface = "0"
        }
      }
    }
    "wan1-vpc1-cloudrouter-1-use4" = {
      region = "us-east4"
      bgp_spoke = {
        asn            = 65036
        advertise_mode = "DEFAULT"
      }
      ncc_interfaces = {
        "0" = {
          subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/wan1-s1-use4"
          ip_address = "10.0.101.5"
        }
        "1" = {
          subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/wan1-s1-use4"
          ip_address          = "10.0.101.6"
          redundant_interface = "0"
        }
      }
    }
  }

  # ── wan2-vpc1 (WAN2 / Cisco NIC 2) ───────────────────────────────────────────
  "wan2-vpc1" = {
    "wan2-vpc1-cloudrouter-1-usc1" = {
      region = "us-central1"
      bgp_spoke = {
        asn            = 65037
        advertise_mode = "DEFAULT"
      }
      ncc_interfaces = {
        "0" = {
          subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/wan2-s1-usc1"
          ip_address = "10.0.11.5"
        }
        "1" = {
          subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-central1/subnetworks/wan2-s1-usc1"
          ip_address          = "10.0.11.6"
          redundant_interface = "0"
        }
      }
    }
    "wan2-vpc1-cloudrouter-1-use4" = {
      region = "us-east4"
      bgp_spoke = {
        asn            = 65038
        advertise_mode = "DEFAULT"
      }
      ncc_interfaces = {
        "0" = {
          subnetwork = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/wan2-s1-use4"
          ip_address = "10.0.111.5"
        }
        "1" = {
          subnetwork          = "projects/rteller-demo-svc-e265-aaac/regions/us-east4/subnetworks/wan2-s1-use4"
          ip_address          = "10.0.111.6"
          redundant_interface = "0"
        }
      }
    }
  }
}

# ─── Firewall Rules ─────────────────────────────────────────────────────────────
firewall_rules = {
  "lan-mgmt-vpc" = {
    "lan-mgmt-vpc-allow-mgmt-access" = {
      description = "Allow management access from known IPs on SSH, HTTP, and HTTPS"
      direction   = "INGRESS"
      ranges      = ["104.53.251.27/32", "35.235.240.0/20"]
      allow = [
        { protocol = "tcp", ports = ["21", "22", "80", "443"] }
      ]
    }
  }

  # ── BGP peering rules ──────────────────────────────────────────────────────────
  # Each rule allows TCP 179 within the subnets where the Cisco router NICs and
  # the Cloud Router NCC interfaces are co-located. Both peers are in the same
  # /24, so using the subnet CIDR as the source range covers both directions.

  "wan1-vpc1" = {
    "wan1-vpc1-allow-bgp" = {
      description = "Allow BGP (TCP 179) between Cisco router and Cloud Router NCC interfaces"
      direction   = "INGRESS"
      ranges      = [
        "10.0.1.0/24",   # wan1-s1-usc1: Cisco Gi2 (.3/.4), CR NCC (.5/.6)
        "10.0.101.0/24", # wan1-s1-use4: Cisco Gi2 (.3/.4), CR NCC (.5/.6)
      ]
      allow = [
        { protocol = "tcp", ports = ["179"] }
      ]
    }
    "wan1-vpc1-allow-iap-ssh" = {
      description = "Allow SSH into test VMs via GCP IAP"
      direction   = "INGRESS"
      ranges      = ["35.235.240.0/20"]
      target_tags = ["test-vm"]
      allow       = [{ protocol = "tcp", ports = ["22"] }]
    }
    "wan1-vpc1-allow-icmp" = {
      description = "Allow ICMP from all RFC1918 ranges for routing verification"
      direction   = "INGRESS"
      ranges      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      allow       = [{ protocol = "icmp" }]
    }
  }

  "wan2-vpc1" = {
    "wan2-vpc1-allow-bgp" = {
      description = "Allow BGP (TCP 179) between Cisco router and Cloud Router NCC interfaces"
      direction   = "INGRESS"
      ranges      = [
        "10.0.11.0/24",  # wan2-s1-usc1: Cisco Gi3 (.3/.4), CR NCC (.5/.6)
        "10.0.111.0/24", # wan2-s1-use4: Cisco Gi3 (.3/.4), CR NCC (.5/.6)
      ]
      allow = [
        { protocol = "tcp", ports = ["179"] }
      ]
    }
    "wan2-vpc1-allow-iap-ssh" = {
      description = "Allow SSH into test VMs via GCP IAP"
      direction   = "INGRESS"
      ranges      = ["35.235.240.0/20"]
      target_tags = ["test-vm"]
      allow       = [{ protocol = "tcp", ports = ["22"] }]
    }
    "wan2-vpc1-allow-icmp" = {
      description = "Allow ICMP from all RFC1918 ranges for routing verification"
      direction   = "INGRESS"
      ranges      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      allow       = [{ protocol = "icmp" }]
    }
  }

  "lan-transit-vpc1" = {
    "lan-transit-vpc1-allow-bgp" = {
      description = "Allow BGP (TCP 179) between Cisco router and Cloud Router NCC interfaces"
      direction   = "INGRESS"
      ranges      = [
        "172.16.1.0/24",   # lan-transit-vpc1-s2-usc1: Cisco Gi4 (.3/.4), CR NCC (.5/.6)
        "172.16.101.0/24", # lan-transit-vpc1-s2-use4: Cisco Gi4 (.3/.4), CR NCC (.5/.6)
      ]
      allow = [
        { protocol = "tcp", ports = ["179"] }
      ]
    }
  }

  "lan-workload-vpc1" = {
    "lan-workload-vpc1-allow-iap-ssh" = {
      description = "Allow SSH into test VMs via GCP IAP"
      direction   = "INGRESS"
      ranges      = ["35.235.240.0/20"]
      target_tags = ["test-vm"]
      allow       = [{ protocol = "tcp", ports = ["22"] }]
    }
    "lan-workload-vpc1-allow-icmp" = {
      description = "Allow ICMP from all RFC1918 ranges for routing verification"
      direction   = "INGRESS"
      ranges      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      allow       = [{ protocol = "icmp" }]
    }
  }
}

# ─── Test VMs ───────────────────────────────────────────────────────────────────
test_vms = {
  "test-vm-wan1-usc1" = {
    vpc    = "wan1-vpc1"
    subnet = "wan1-s2-usc1"      # 10.0.2.0/24 — avoids Cisco/Cloud Router subnet
    region = "us-central1"
    zone   = "us-central1-a"
  }
  "test-vm-wan2-usc1" = {
    vpc    = "wan2-vpc1"
    subnet = "wan2-s2-usc1"      # 10.0.12.0/24
    region = "us-central1"
    zone   = "us-central1-a"
  }
  "test-vm-lan-usc1" = {
    vpc    = "lan-workload-vpc1"
    subnet = "lan-workload-vpc1-s1-usc1"   # 192.168.1.0/24
    region = "us-central1"
    zone   = "us-central1-a"
  }
}

# ─── NSI (Network Security Integration) ─────────────────────────────────────────
# All traffic reaching the consumer VPCs below is intercepted via GENEVE and
# sent to the Palo Alto firewall (NIC 1 in palo-producer-vpc1) for inspection.
# deployment1 = adt-lab-palo-usc1 (us-central1-a)
# deployment2 = adt-lab-palo-use4 (us-east4-a)

nsi_name_prefix = "adt-lab-nsi"

nsi_consumer_vpc_names = [
  "wan1-vpc1",
  "wan2-vpc1",
  "lan-transit-vpc1",
  "lan-workload-vpc1",
  "lan-mgmt-vpc",
]

nsi_intercept_rules = [
  {
    priority    = 1000
    direction   = "INGRESS"
    description = "Intercept all ingress traffic — send to Palo Alto via GENEVE for inspection"
  },
  {
    priority    = 1001
    direction   = "EGRESS"
    description = "Intercept all egress traffic — send to Palo Alto via GENEVE for inspection"
  },
]
