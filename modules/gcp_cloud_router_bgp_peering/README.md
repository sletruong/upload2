# BGP Peering Module

## Overview

This Terraform module sets up BGP peering for a Google Cloud Platform (GCP) environment. It leverages the `google_compute_router_peer` resource to configure BGP peers for a Cloud Router.

## Configuration

### Variables

The module requires several variables to be defined, which are specified in the `variables.tf` file.

#### `project_id`

- **Description**: The ID of the project where this VPC will be created.
- **Type**: `string`

#### `bgp_peering`

- **Description**: The BGP peering configuration.
- **Type**: `object`

| Field                  | Type   | Description                                                                        | Default Value     | Overridden at Peer Level |
| ---------------------- | ------ | ---------------------------------------------------------------------------------- | ----------------- | ------------------------ |
| `instance_address`     | string | The IP address of the instance.                                                    | N/A               | No                       |
| `instance_asn`         | number | The ASN of the instance.                                                           | N/A               | No                       |
| `instance_name`        | string | The name of the instance.                                                          | N/A               | No                       |
| `instance_self_link`   | string | The self-link of the instance.                                                     | N/A               | No                       |
| `instance_zone`        | string | The zone of the instance.                                                          | N/A               | No                       |
| `subnetwork_name`      | string | The name of the subnetwork.                                                        | N/A               | No                       |
| `cloud_router_name`    | string | The name of the cloud router.                                                      | `null`            | Yes                      |
| `advertise_mode`       | string | The advertise mode for the BGP peering.                                            | `"DEFAULT"`       | Yes                      |
| `advertised_groups`    | list   | The advertised groups for the BGP peering.                                         | `["ALL_SUBNETS"]` | Yes                      |
| `advertised_ip_ranges` | list   | The advertised IP ranges for the BGP peering.                                      | `[]`              | Yes                      |
| `peers`                | list   | List of peer objects. Each peer object can override certain instance-level fields. | N/A               | N/A                      |

#### Peer Object

| Field                     | Type   | Description                                   | Default Value |
| ------------------------- | ------ | --------------------------------------------- | ------------- |
| `enable`                  | bool   | Enable flag for the BGP peering.              | `true`        |
| `peer_name`               | string | The name of the peer.                         | `null`        |
| `cloud_router_nic_number` | number | The NIC number of the cloud router.           | `null`        |
| `cloud_router_nic_name`   | string | The NIC name of the cloud router.             | `null`        |
| `priority`                | number | The priority of the advertised route.         | `100`         |
| `cloud_router_name`       | string | The name of the cloud router.                 | `null`        |
| `advertise_mode`          | string | The advertise mode for the BGP peering.       | `null`        |
| `advertised_groups`       | list   | The advertised groups for the BGP peering.    | `null`        |
| `advertised_ip_ranges`    | list   | The advertised IP ranges for the BGP peering. | `null`        |

### Validations

- At least one BGP peer must be configured.
- Either `cloud_router_nic_number` or `cloud_router_nic_name` must be provided for each BGP peer.
- Either `cloud_router_name` must be provided for each BGP peer or the `cloud_router_name` at the instance level must be provided.
- The `peer_name` is generated using the format: `"{cloud_router_name}-peer-{UUID}"`, where `UUID` is a unique identifier based on the instance and peer configuration.

## Functionality

The main functionality is defined in the `main.tf` file, which configures the `google_compute_router_peer` resource.

### `google_compute_router_peer` Resource

- **for_each**: Iterates over the BGP peers defined in the `bgp_peering` variable. The key for each peer is generated using the format: `"{cloud_router_name}-peer-{UUID}"`, where `UUID` is a unique identifier based on the instance and peer configuration.
- **project**: Uses the `project_id` variable.
- **name**: Sets the name of the peer. If `peer_name` is not provided, it is generated using the format: `"{cloud_router_name}-peer-{UUID}"`.
- **enable**: Enables or disables the peer based on the `enable` field in the peer object.
- **router**: Sets the cloud router name. It uses the `cloud_router_name` from the peer object if provided; otherwise, it falls back to the instance-level `cloud_router_name`.
- **region**: Extracts the region from the instance zone.
- **interface**: Configures the interface name. It uses the `cloud_router_nic_name` from the peer object if provided; otherwise, it falls back to the instance-level `cloud_router_nic_name`.
- **peer_asn**: Sets the ASN of the peer.
- **advertise_mode**: Configures the advertise mode. It uses the `advertise_mode` from the peer object if provided; otherwise, it falls back to the instance-level `advertise_mode`.
- **advertised_groups**: Configures the advertised groups. It uses the `advertised_groups` from the peer object if provided; otherwise, it falls back to the instance-level `advertised_groups`.
- **dynamic "advertised_ip_ranges"**: Configures the advertised IP ranges dynamically. It uses the `advertised_ip_ranges` from the peer object if provided; otherwise, it falls back to the instance-level `advertised_ip_ranges`.
- **router_appliance_instance**: Sets the self-link of the router appliance instance.
- **peer_ip_address**: Sets the IP address of the peer.
- **advertised_route_priority**: Sets the priority of the advertised route.

## Usage

To use this module, include it in your Terraform configuration and pass the required variables. Example:

```hcl
module "bgp_peering" {
  source = "./modules/router_bgp_peering"

  project_id = var.project_id
  bgp_peering = {
    instance_address   = "10.0.0.1"
    instance_asn       = 65001
    instance_name      = "instance-1"
    instance_self_link = "https://www.googleapis.com/compute/v1/projects/project-id/zones/zone/instances/instance-1"
    instance_zone      = "us-central1-a"
    subnetwork_name    = "subnetwork-1"
    cloud_router_name  = "cloud-router-1"
    advertise_mode     = "DEFAULT"
    advertised_groups  = ["ALL_SUBNETS"]
    advertised_ip_ranges = []

    peers = [
      {
        enable                  = true
        peer_name               = "peer-1"
        cloud_router_nic_number = 0
        cloud_router_nic_name   = "nic0"
        priority                = 100
        cloud_router_name       = "cloud-router-1"
        advertise_mode          = "DEFAULT"
        advertised_groups       = ["ALL_SUBNETS"]
        advertised_ip_ranges    = []
      }
    ]
  }
}
```