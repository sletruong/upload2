## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_subnet_iam_add_member_role"></a> [subnet\_iam\_add\_member\_role](#module\_subnet\_iam\_add\_member\_role) | ../subnet_iam_add_member_role | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_subnetwork.subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_network.cur-net](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | The name of the network where routes will be created | `any` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project where the routes will be created | `any` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | map of subnets objects. | <pre>map(object({<br>	  subnet_ip                     = string<br>	  subnet_region                 = string<br>	  subnet_private_access         = bool<br>	  subnet_flow_logs              = bool<br>	  subnet_flow_logs_filter       = bool<br>	  subnet_flow_logs_interval     = string<br>	  subnet_flow_logs_sampling     = number<br>	  subnet_flow_logs_metadata     = string <br>	  secondary_ranges = map(object({<br>	    ip_cidr_range = string<br>      }))<br>	  # only valid value INTERNAL_HTTPS_LOAD_BALANCER<br>	  # if INTERNAL_HTTPS_LOAD_BALANCER the either ACTIVE or BACKUP<br>	  purpose                       = string	<br>	  role                          = string 	<br>      #	  <br>	  iam_roles = map(object({<br>	    role    = string<br>	    members = list(string)<br>      }))  <br>	}))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_iam"></a> [iam](#output\_iam) | etags of policies |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | The created subnet resources |
