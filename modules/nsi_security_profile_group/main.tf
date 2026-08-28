# NSI security profile group — the SELECTABLE HANDLE for the intercept (or
# mirroring) chain. A firewall rule names THIS via
# action = apply_security_profile_group.
#
# OWN FAMILY, NOT NESTED: mirrors how Cloud NGFW SPGs
# already work — defined in their own family, referenced where used. One SPG
# may serve several endpoint groups.
#
# ⚠ MONOLITHIC: profiles are inline string references with NO membership
# resource, so exactly ONE state may own a given SPG.
#
# ⚠ AN SPG WITH NO PROFILE FAILS OPEN — the rule applies and traffic PASSES.
# `endpoint_group` is therefore required by this module, not optional.

locals {
  parent     = coalesce(var.target, "projects/${var.project_id}")
  is_mirror  = var.type == "MIRROR"
  profile_id = var.name
}

resource "google_network_security_security_profile" "this" {
  name     = local.profile_id
  parent   = local.parent
  location = "global"
  # the document's INTERCEPT/MIRROR selects the PROFILE TYPE
  type        = local.is_mirror ? "CUSTOM_MIRRORING" : "CUSTOM_INTERCEPT"
  description = var.description

  dynamic "custom_intercept_profile" {
    for_each = local.is_mirror ? [] : [1]
    content {
      intercept_endpoint_group = var.endpoint_group
    }
  }

  dynamic "custom_mirroring_profile" {
    for_each = local.is_mirror ? [1] : []
    content {
      mirroring_endpoint_group = var.endpoint_group
    }
  }
}

resource "google_network_security_security_profile_group" "this" {
  name        = var.name
  parent      = local.parent
  location    = "global"
  description = var.description

  custom_intercept_profile = local.is_mirror ? null : google_network_security_security_profile.this.id
  custom_mirroring_profile = local.is_mirror ? google_network_security_security_profile.this.id : null
}
