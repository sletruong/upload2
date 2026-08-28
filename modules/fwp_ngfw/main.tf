# NGFW enablement primitives (tier 0): firewall endpoints + security
# profiles/groups (THREAT_PREVENTION and/or URL_FILTERING per group).
# Firewall policies DEPEND on this module — rules with action =
# apply_security_profile_group reference the group ids output here.
# Endpoint->VPC associations are stage-1 (they share the VPC lifecycle);
# groups never reference endpoints (no such GCP link).

locals {
  tp_groups = { for k, g in var.security_profile_groups : k => g if g.profiles.threat_prevention != null }
  uf_groups = { for k, g in var.security_profile_groups : k => g if g.profiles.url_filtering != null }
}

resource "google_network_security_security_profile" "threat_prevention" {
  for_each = local.tp_groups

  name        = each.value.profiles.threat_prevention.name
  parent      = each.value.parent
  location    = "global"
  description = each.value.description
  type        = "THREAT_PREVENTION"

  # Emitted only when overrides exist: the API does not store an empty
  # threat_prevention_profile block, so declaring one permadiffs every plan.
  dynamic "threat_prevention_profile" {
    for_each = length(merge(
      each.value.profiles.threat_prevention.severity_overrides,
      each.value.profiles.threat_prevention.signature_overrides,
      each.value.profiles.threat_prevention.antivirus_overrides
    )) > 0 ? [1] : []
    content {
      dynamic "severity_overrides" {
        for_each = each.value.profiles.threat_prevention.severity_overrides
        content {
          severity = severity_overrides.key
          action   = severity_overrides.value
        }
      }

      # framework lexicon: signature_overrides -> provider threat_overrides
      dynamic "threat_overrides" {
        for_each = each.value.profiles.threat_prevention.signature_overrides
        content {
          threat_id = threat_overrides.key
          action    = threat_overrides.value
        }
      }

      dynamic "antivirus_overrides" {
        for_each = each.value.profiles.threat_prevention.antivirus_overrides
        content {
          protocol = antivirus_overrides.key
          action   = antivirus_overrides.value
        }
      }
    }
  }
}

resource "google_network_security_security_profile" "url_filtering" {
  for_each = local.uf_groups

  name        = each.value.profiles.url_filtering.name
  parent      = each.value.parent
  location    = "global"
  description = each.value.description
  type        = "URL_FILTERING"

  url_filtering_profile {
    dynamic "url_filters" {
      for_each = each.value.profiles.url_filtering.url_filters
      content {
        priority         = url_filters.value.priority
        filtering_action = url_filters.value.action
        urls             = url_filters.value.urls
      }
    }
  }
}

resource "google_network_security_security_profile_group" "group" {
  for_each = var.security_profile_groups

  name                      = each.value.name
  parent                    = each.value.parent
  location                  = "global"
  description               = each.value.description
  threat_prevention_profile = each.value.profiles.threat_prevention != null ? google_network_security_security_profile.threat_prevention[each.key].id : null
  url_filtering_profile     = each.value.profiles.url_filtering != null ? google_network_security_security_profile.url_filtering[each.key].id : null
}

resource "google_network_security_firewall_endpoint" "endpoint" {
  for_each = var.endpoints

  name               = each.value.name
  parent             = each.value.parent
  location           = each.value.zone
  billing_project_id = each.value.billing_project_id
  labels             = each.value.labels
}
