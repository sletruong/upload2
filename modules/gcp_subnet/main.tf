/******************************************
	Subnet configuration
 *****************************************/
resource "google_compute_subnetwork" "subnetwork" {
  for_each                 = var.subnets
  name                     = each.key
  ip_cidr_range            = each.value.subnet_ip
  region                   = each.value.subnet_region
  private_ip_google_access = lookup(each.value, "subnet_private_access", "false")

  dynamic "log_config" {
    for_each = lookup(each.value, "subnet_flow_logs", false) ? [{
      aggregation_interval = lookup(each.value, "subnet_flow_logs_interval", "INTERVAL_5_SEC")
      flow_sampling        = lookup(each.value, "subnet_flow_logs_sampling", "0.5")
      metadata             = lookup(each.value, "subnet_flow_logs_metadata", "INCLUDE_ALL_METADATA")
      filter_expr          = lookup(each.value, "subnet_flow_logs_filter", "true")
    }] : []
    content {
      aggregation_interval = log_config.value.aggregation_interval
      flow_sampling        = log_config.value.flow_sampling
      metadata             = log_config.value.metadata
      filter_expr          = log_config.value.filter_expr
    }
  }

  network     = var.network_name
  project     = var.project_id
  description = lookup(each.value, "description", null)

  dynamic "secondary_ip_range" {
    for_each = lookup(each.value, "secondary_ranges", {}) != null ? lookup(each.value, "secondary_ranges", {}) : {}
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  purpose = lookup(each.value, "purpose", null)
  role    = lookup(each.value, "role", null)
}

module "subnet_iam_add_member_role" {
  source          = "../gcp_subnet_iam_add_member_role"
  project_id      = var.project_id
  network_name    = var.network_name
  for_each        = var.subnets
  subnetwork_name = each.key
  region          = each.value.subnet_region
  iam_roles       = lookup(each.value, "iam_roles", {})
  depends_on      = [google_compute_subnetwork.subnetwork]
}