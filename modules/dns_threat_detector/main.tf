# DNS Armor — Infoblox-powered DNS-layer threat DETECTION.
#
# ⚠ DETECTION, NOT PREVENTION. Analysis is ASYNCHRONOUS, performed AFTER the
# query resolves, so it adds no latency and BLOCKS NOTHING. Findings land in
# Cloud Logging. If you need a query actually stopped, that is an RPZ
# response policy (a different family in this same tier).
#
# ⚠ IT ONLY SEES INTERNET-BOUND QUERIES RESOLVED VIA THE METADATA SERVER IN
# A NON-PEERED VPC. Everything below is EXCLUDED by GCP, and none of it is
# visible from this resource:
#   - DNS PEERING zones — even internet-bound queries crossing a peering
#     connection are NOT inspected. A spoke with a root `.` peering zone to
#     a hub is entirely invisible. THIS GUTS HUB-AND-SPOKE ESTATES.
#   - inbound forwarding endpoints
#   - hybrid (VPN/Interconnect) via server policies or forwarding zones
#   - Cloud DNS private zones (incl. Service Directory)
#   - GCE internal DNS (`.internal`)
#   - serverless: Cloud Run, Cloud Run functions, App Engine standard
#   - Secure Web Proxy's own DNS queries
#   - any workload pointed at a resolver other than 169.254.169.254
#
# An estate can enable this, be BILLED for it, and inspect almost nothing —
# with no signal anywhere that coverage is near zero. Verify the resolution
# path before trusting the absence of findings.
#
# ⚠ BILLING: per internet-bound query analysed, PLUS the Cloud Logging cost
# of findings. `.internal` and RFC 2606 TLDs are dropped free, but
# `.local` / `.localdomain` are RECURSED to the internet — billed and
# inspected.
resource "google_network_security_dns_threat_detector" "this" {
  provider = google-beta

  project  = var.project_id
  name     = var.name
  location = "global" # provider: the only supported value

  # provider: the only supported value
  threat_detector_provider = "INFOBLOX"

  excluded_networks = var.excluded_networks
  labels            = var.labels
}
