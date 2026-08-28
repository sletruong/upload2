# Serverless VPC Access connector (fabric): the bridge that lets Cloud Run
# gen1 / Cloud Functions / App Engine reach this VPC. Regional; billed
# ALWAYS-ON (min 2 instances — never scales to zero). Two IP modes: claim a
# /28 (CIDR mode) or consume a DEDICATED /28 subnet (subnet mode).
# NOTE: Direct VPC egress is the successor pattern for Cloud Run gen2 —
# no connector resource at all, the workload attaches to an ordinary subnet
# at deploy time; the fabric just provides subnet IP headroom.

resource "google_vpc_access_connector" "connector" {
  project = var.project_id
  name    = var.name
  region  = var.region

  # CIDR mode
  network       = var.network
  ip_cidr_range = var.ipv4_cidr

  # Subnet mode (dedicated /28)
  dynamic "subnet" {
    for_each = var.subnet != null ? [var.subnet] : []
    content {
      name = element(reverse(split("/", subnet.value)), 0)
    }
  }

  machine_type  = var.machine_type
  min_instances = var.min_instances
  max_instances = var.max_instances
}
