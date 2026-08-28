## Introduction

This module is used to configure the Cisco catalyst routers.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google-beta_google_compute_instance.this](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_compute_instance) | resource |
| [google_compute_address.private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.public](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable deletion protection on the instance. | `bool` | `false` | no |
| <a name="input_image"></a> [image](#input\_image) | Cisco catalyst 8000v image | `string` | `"https://www.googleapis.com/compute/v1/projects/cisco-public/global/images/cisco-c8k-17-14-01a"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | GCP instance lables. | `map(any)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Instance machine type | `string` | n/a | yes |
| <a name="input_min_cpu_platform"></a> [min\_cpu\_platform](#input\_min\_cpu\_platform) | Minimum CPU platform for the compute instance. Up to date version can be found [here](https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform). | `string` | `"Intel Cascade Lake"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the cisco router | `string` | n/a | yes |
| <a name="input_network_interfaces"></a> [network\_interfaces](#input\_network\_interfaces) | List of the network interface specifications.<br>Available options:<br>- `subnetwork`             - (Required\|string) Self-link of a subnetwork to create interface in.<br>- `private_ip_name`        - (Optional\|string) Name for a private address to reserve.<br>- `private_ip`             - (Optional\|string) Private address to reserve.<br>- `create_public_ip`       - (Optional\|boolean) Whether to reserve public IP for the interface. Ignored if `public_ip` is provided. Defaults to 'false'.<br>- `public_ip_name`         - (Optional\|string) Name for a public address to reserve.<br>- `public_ip`              - (Optional\|string) Existing public IP to use.<br>- `public_ptr_domain_name` - (Optional\|string) Existing public PTR name to use.<br>- `network_attachment`     - optional(string)<br>- `alias_ip_ranges`        - (Optional\|list) List of objects that define additional IP ranges for an interface, as specified [here](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#ip_cidr_range) | `list(any)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project where the routes will be created | `string` | n/a | yes |
| <a name="input_resource_policies"></a> [resource\_policies](#input\_resource\_policies) | n/a | `list(string)` | `[]` | no |
| <a name="input_scopes"></a> [scopes](#input\_scopes) | n/a | `list(string)` | <pre>[<br>  "https://www.googleapis.com/auth/compute.readonly",<br>  "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br>  "https://www.googleapis.com/auth/devstorage.read_only",<br>  "https://www.googleapis.com/auth/logging.write",<br>  "https://www.googleapis.com/auth/monitoring.write"<br>]</pre> | no |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Service account associated with the instance | `string` | n/a | yes |
| <a name="input_startup-script"></a> [startup-script](#input\_startup-script) | startup-script | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | GCP instance tags. | `list(string)` | `[]` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | zone where the cisco router is deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance"></a> [instance](#output\_instance) | n/a |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | n/a |