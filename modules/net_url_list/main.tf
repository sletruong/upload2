# Named URL list — the reusable half of URL filtering.
#
# TWO CONSUMERS, TWO DIFFERENT PRODUCTS (.claude/LEXICON.md §1):
#   - Secure Web Proxy   -> gateway_security_policy_rule.application_matcher
#   - Cloud NGFW         -> a url_filtering security profile in an SPG
# The list itself is neutral; the consumer decides what matching it drives.
#
# A list is INERT until something references it. Creating one grants and
# denies nothing.
resource "google_network_security_url_lists" "this" {
  project     = var.project_id
  name        = var.name
  location    = var.region
  description = var.description
  values      = var.values
}
