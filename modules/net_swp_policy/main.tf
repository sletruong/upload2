# Secure Web Proxy policy + its rules.
#
# SWP IS NOT CLOUD NGFW AND NOT NSI (.claude/LEXICON.md §1). It is an explicit/transparent
# HTTP(S) proxy: it terminates the session and matches on L7. Cloud NGFW
# inspects in the data path via a firewall-policy rule naming an SPG; these
# two never substitute for each other, even when both carry "URL filtering".
#
# ⚠ WITHOUT a tls_inspection_policy the proxy sees SNI/host only. Rules that
# read as path-scoped quietly become host-scoped — allowed, and wrong.
resource "google_network_security_gateway_security_policy" "this" {
  project               = var.project_id
  name                  = var.name
  location              = var.region
  description           = var.description
  tls_inspection_policy = var.tls_inspection_policy
}

resource "google_network_security_gateway_security_policy_rule" "this" {
  for_each = var.rules

  project                 = var.project_id
  location                = var.region
  name                    = each.key
  gateway_security_policy = google_network_security_gateway_security_policy.this.name
  priority                = each.value.priority
  session_matcher         = each.value.session_matcher
  application_matcher     = each.value.application_matcher
  basic_profile           = each.value.basic_profile
  enabled                 = each.value.enabled
  tls_inspection_enabled  = each.value.tls_inspection_enabled
  description             = each.value.description
}
