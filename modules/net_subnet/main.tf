# Fabric subnet: belongs to a VPC in the SAME state — the caller passes the
# resolved network self link, so create order is VPC-then-subnet and destroy
# order is subnet-then-VPC automatically. Secondary ranges, Private Google
# Access, and flow logs cascade from deployment defaults at the stack layer;
# this module receives final values only.

resource "google_compute_subnetwork" "subnet" {
  project = var.project_id
  name    = var.name
  region  = var.region
  network = var.network

  ip_cidr_range            = var.ipv4_cidr
  description              = var.description
  private_ip_google_access = var.private_ip_google_access
  purpose                  = var.purpose
  role                     = var.role

  # hybrid subnets: on-prem more-specific routes may claim in-subnet IPs
  allow_subnet_cidr_routes_overlap = var.allow_cidr_routes_overlap ? true : null
  resolve_subnet_mask              = var.resolve_subnet_mask

  # dual stack; explicit v6 range routes by access type (else auto-assigned)
  stack_type                 = var.stack_type
  ipv6_access_type           = var.ipv6_access_type
  private_ipv6_google_access = var.private_ipv6_google_access
  external_ipv6_prefix       = var.ipv6_access_type == "EXTERNAL" ? var.ipv6_cidr : null
  internal_ipv6_prefix       = var.ipv6_access_type == "INTERNAL" ? var.ipv6_cidr : null

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ranges
    content {
      range_name    = secondary_ip_range.value.name
      ip_cidr_range = secondary_ip_range.value.ipv4_cidr
    }
  }

  # removing the LAST secondary range silently no-ops without this (hygiene)
  send_secondary_ip_range_if_empty = true

  dynamic "log_config" {
    for_each = var.flow_logs.enabled ? [1] : []
    content {
      aggregation_interval = var.flow_logs.aggregation_interval
      flow_sampling        = var.flow_logs.sampling
      metadata             = var.flow_logs.metadata
      filter_expr          = var.flow_logs.filter_expr
      metadata_fields      = var.flow_logs.metadata == "CUSTOM_METADATA" ? var.flow_logs.metadata_fields : null
    }
  }
}

resource "google_compute_subnetwork_iam_binding" "iam" {
  for_each = var.iam

  project    = var.project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.subnet.name
  role       = each.key
  members    = each.value
}
