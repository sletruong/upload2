## Requirements

No requirements.

## Providers

| Name                                                       | Version |
| ---------------------------------------------------------- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | n/a     |

## Modules

No modules.

## Resources

| Name                                                                                                                                | Type        |
| ----------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router)       | resource    |
| [google_compute_network.cur-net](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |

## General Router Configuration

| Name           | Description                                                                             | Type     | Default | Required |
| -------------- | --------------------------------------------------------------------------------------- | -------- | ------- | :------: |
| `project_id`   | The Google Cloud project ID where the router and associated resources will be deployed. | `string` | n/a     |   yes    |
| `network_name` | The name of the Google Cloud VPC network where the router is connected.                 | `string` | n/a     |   yes    |

## Router Specific Configuration[`var.routers.*`]

| Name          | Description                              | Type     | Default | Required |
| ------------- | ---------------------------------------- | -------- | ------- | :------: |
| `router_name` | Name of the Cloud Router.                | `string` | n/a     |   yes    |
| `region`      | The region where the router is deployed. | `string` | n/a     |   yes    |

### Network Connectivity Center Interfaces (NCC Interfaces) [`var.routers.*.ncc_interfaces`]

| Name                  | Description                                    | Type     | Default | Required |
| --------------------- | ---------------------------------------------- | -------- | ------- | :------: |
| `ip_address`          | IP address assigned to the interface.          | `string` | n/a     |   yes    |
| `redundant_interface` | Secondary interface for redundancy (optional). | `string` | `null`  |    no    |


### Cloud NAT Configuration [`var.routers.*.cloud_nat`]

| Name                                  | Description                                                 | Type           | Default                           | Required |
| ------------------------------------- | ----------------------------------------------------------- | -------------- | --------------------------------- | :------: |
| `source_subnetwork_ip_ranges_to_nat`  | Defines which IP ranges of the subnetwork should be NAT'ed. | `string`       | `"ALL_SUBNETWORKS_ALL_IP_RANGES"` |    no    |
| `external_nat_ip_dynamic`             | Whether the external IP should be dynamically allocated.    | `bool`         | `false`                           |    no    |
| `external_nat_ip_count`               | Number of external IPs to allocate for NAT.                 | `number`       | `0`                               |    no    |
| `external_nat_ip_list`                | Specific list of external IPs to be used for NAT.           | `list(string)` | `[]`                              |    no    |
| `enable_dynamic_port_allocation`      | Enable dynamic port allocation for NAT.                     | `bool`         | n/a                               |    no    |
| `enable_endpoint_independent_mapping` | Enable endpoint independent mapping.                        | `bool`         | n/a                               |    no    |
| `tcp_established_idle_timeout_sec`    | Idle timeout in seconds for established TCP connections.    | `number`       | n/a                               |    no    |
| `log_config_enable`                   | Enable logging for NAT.                                     | `bool`         | n/a                               |    no    |
| `log_config_filter`                   | Filter type for logging.                                    | `string`       | n/a                               |    no    |
| `icmp_idle_timeout_sec`               | Idle timeout in seconds for ICMP connections.               | `number`       | n/a                               |    no    |
| `tcp_transitory_idle_timeout_sec`     | Idle timeout in seconds for transitory TCP connections.     | `number`       | n/a                               |    no    |
| `udp_idle_timeout_sec`                | Idle timeout in seconds for UDP connections.                | `number`       | n/a                               |    no    |
| `min_ports_per_vm`                    | Minimum number of ports per VM for NAT.                     | `number`       | n/a                               |    no    |
| `max_ports_per_vm`                    | Maximum number of ports per VM for NAT.                     | `number`       | n/a                               |    no    |


### BGP Configuration [`var.routers.*.bgp_spoke`]

| Name                   | Description                                                 | Type           | Default           | Required |
| ---------------------- | ----------------------------------------------------------- | -------------- | ----------------- | :------: |
| `asn`                  | Autonomous System Number for BGP.                           | `number`       | n/a               |   yes    |
| `advertise_mode`       | Mode of advertisement for BGP.                              | `string`       | `"CUSTOM"`        |    no    |
| `advertised_groups`    | Groups of IP ranges to advertise.                           | `list(string)` | `["ALL_SUBNETS"]` |    no    |
| `advertised_ip_ranges` | Specific IP ranges to advertise with optional descriptions. | `list(object)` | `[]`              |    no    |


## Outputs

| Name                                                                    | Description |
| ----------------------------------------------------------------------- | ----------- |
| <a name="output_router_id"></a> [router\_id](#output\_router\_id)       | n/a         |
| <a name="output_router_link"></a> [router\_link](#output\_router\_link) | n/a         |
| <a name="output_cloud_nat"></a> [cloud\_nat](#output\_cloud\_nat)       | n/a         |
