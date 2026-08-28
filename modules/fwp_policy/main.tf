# ONE module for all three firewall policy types (user decision):
#   type = "hierarchical" -> google_compute_firewall_policy (org/folder parent,
#                            container associations owned here — module opinion)
#   type = "global"       -> google_compute_network_firewall_policy
#   type = "regional"     -> google_compute_region_network_firewall_policy
# Rules with action = apply_security_profile_group carry the SPG id resolved by
# the caller from fwp_ngfw outputs — that reference IS the dependency ordering
# GCP requires (SPG before the rule that references it).

locals {
  is_hier     = var.type == "hierarchical"
  is_global   = var.type == "global"
  is_regional = var.type == "regional"

  # Target normalization lives IN the module: bare digits = folder id.
  parent = var.parent == null ? null : (can(regex("^[0-9]+$", var.parent)) ? "folders/${var.parent}" : var.parent)
}

# ---- hierarchical ----
resource "google_compute_firewall_policy" "hierarchical" {
  count = local.is_hier ? 1 : 0

  parent      = local.parent
  short_name  = var.name
  description = var.description
}

resource "google_compute_firewall_policy_rule" "hierarchical" {
  for_each = local.is_hier ? var.rules : {}

  firewall_policy         = google_compute_firewall_policy.hierarchical[0].id
  priority                = each.value.priority
  description             = each.value.description
  direction               = each.value.direction
  action                  = each.value.action
  enable_logging          = each.value.logging
  disabled                = !each.value.enabled # lexicon owns the polarity flip
  security_profile_group  = each.value.security_profile_group
  tls_inspect             = each.value.tls_inspect ? true : null
  target_service_accounts = length(each.value.target_service_accounts) > 0 ? each.value.target_service_accounts : null
  target_resources        = length(each.value.target_networks) > 0 ? each.value.target_networks : null

  match {
    src_ip_ranges             = length(each.value.source_ranges) > 0 ? each.value.source_ranges : null
    dest_ip_ranges            = length(each.value.destination_ranges) > 0 ? each.value.destination_ranges : null
    src_address_groups        = length(each.value.source_address_groups) > 0 ? each.value.source_address_groups : null
    dest_address_groups       = length(each.value.destination_address_groups) > 0 ? each.value.destination_address_groups : null
    src_fqdns                 = length(each.value.source_fqdns) > 0 ? each.value.source_fqdns : null
    dest_fqdns                = length(each.value.destination_fqdns) > 0 ? each.value.destination_fqdns : null
    src_region_codes          = length(each.value.source_region_codes) > 0 ? each.value.source_region_codes : null
    dest_region_codes         = length(each.value.destination_region_codes) > 0 ? each.value.destination_region_codes : null
    src_threat_intelligences  = length(each.value.source_threat_intelligence) > 0 ? each.value.source_threat_intelligence : null
    dest_threat_intelligences = length(each.value.destination_threat_intelligence) > 0 ? each.value.destination_threat_intelligence : null
    src_network_context       = each.value.source_network_context
    dest_network_context      = each.value.destination_network_context
    src_networks              = length(each.value.source_networks) > 0 ? each.value.source_networks : null

    dynamic "src_secure_tags" {
      for_each = each.value.source_secure_tags
      content {
        name = src_secure_tags.value
      }
    }

    dynamic "layer4_configs" {
      for_each = each.value.layer4
      content {
        ip_protocol = layer4_configs.value.protocol
        ports       = layer4_configs.value.ports
      }
    }
  }

  dynamic "target_secure_tags" {
    for_each = each.value.target_secure_tags
    content {
      name = target_secure_tags.value
    }
  }
}

resource "google_compute_firewall_policy_association" "hierarchical" {
  for_each = local.is_hier ? merge(var.associations, var.associate_parent ? { parent = local.parent } : {}) : {}

  firewall_policy   = google_compute_firewall_policy.hierarchical[0].id
  attachment_target = each.value
  name              = "${var.name}-${each.key}"
}

# ---- global ----
resource "google_compute_network_firewall_policy" "global" {
  count = local.is_global ? 1 : 0

  project     = var.project_id
  name        = var.name
  description = var.description
}

resource "google_compute_network_firewall_policy_rule" "global" {
  for_each = local.is_global ? var.rules : {}

  project                 = var.project_id
  firewall_policy         = google_compute_network_firewall_policy.global[0].name
  priority                = each.value.priority
  description             = each.value.description
  direction               = each.value.direction
  action                  = each.value.action
  enable_logging          = each.value.logging
  disabled                = !each.value.enabled # lexicon owns the polarity flip
  security_profile_group  = each.value.security_profile_group
  tls_inspect             = each.value.tls_inspect ? true : null
  target_service_accounts = length(each.value.target_service_accounts) > 0 ? each.value.target_service_accounts : null

  match {
    src_ip_ranges             = length(each.value.source_ranges) > 0 ? each.value.source_ranges : null
    dest_ip_ranges            = length(each.value.destination_ranges) > 0 ? each.value.destination_ranges : null
    src_address_groups        = length(each.value.source_address_groups) > 0 ? each.value.source_address_groups : null
    dest_address_groups       = length(each.value.destination_address_groups) > 0 ? each.value.destination_address_groups : null
    src_fqdns                 = length(each.value.source_fqdns) > 0 ? each.value.source_fqdns : null
    dest_fqdns                = length(each.value.destination_fqdns) > 0 ? each.value.destination_fqdns : null
    src_region_codes          = length(each.value.source_region_codes) > 0 ? each.value.source_region_codes : null
    dest_region_codes         = length(each.value.destination_region_codes) > 0 ? each.value.destination_region_codes : null
    src_threat_intelligences  = length(each.value.source_threat_intelligence) > 0 ? each.value.source_threat_intelligence : null
    dest_threat_intelligences = length(each.value.destination_threat_intelligence) > 0 ? each.value.destination_threat_intelligence : null
    src_network_context       = each.value.source_network_context
    dest_network_context      = each.value.destination_network_context
    src_networks              = length(each.value.source_networks) > 0 ? each.value.source_networks : null

    dynamic "src_secure_tags" {
      for_each = each.value.source_secure_tags
      content {
        name = src_secure_tags.value
      }
    }

    dynamic "layer4_configs" {
      for_each = each.value.layer4
      content {
        ip_protocol = layer4_configs.value.protocol
        ports       = layer4_configs.value.ports
      }
    }
  }

  dynamic "target_secure_tags" {
    for_each = each.value.target_secure_tags
    content {
      name = target_secure_tags.value
    }
  }
}

# ---- regional ----
resource "google_compute_region_network_firewall_policy" "regional" {
  count = local.is_regional ? 1 : 0

  project     = var.project_id
  name        = var.name
  description = var.description
  region      = var.region
}

resource "google_compute_region_network_firewall_policy_rule" "regional" {
  for_each = local.is_regional ? var.rules : {}

  project                 = var.project_id
  region                  = var.region
  firewall_policy         = google_compute_region_network_firewall_policy.regional[0].name
  priority                = each.value.priority
  description             = each.value.description
  direction               = each.value.direction
  action                  = each.value.action
  enable_logging          = each.value.logging
  disabled                = !each.value.enabled # lexicon owns the polarity flip
  security_profile_group  = each.value.security_profile_group
  tls_inspect             = each.value.tls_inspect ? true : null
  target_service_accounts = length(each.value.target_service_accounts) > 0 ? each.value.target_service_accounts : null

  match {
    src_ip_ranges             = length(each.value.source_ranges) > 0 ? each.value.source_ranges : null
    dest_ip_ranges            = length(each.value.destination_ranges) > 0 ? each.value.destination_ranges : null
    src_address_groups        = length(each.value.source_address_groups) > 0 ? each.value.source_address_groups : null
    dest_address_groups       = length(each.value.destination_address_groups) > 0 ? each.value.destination_address_groups : null
    src_fqdns                 = length(each.value.source_fqdns) > 0 ? each.value.source_fqdns : null
    dest_fqdns                = length(each.value.destination_fqdns) > 0 ? each.value.destination_fqdns : null
    src_region_codes          = length(each.value.source_region_codes) > 0 ? each.value.source_region_codes : null
    dest_region_codes         = length(each.value.destination_region_codes) > 0 ? each.value.destination_region_codes : null
    src_threat_intelligences  = length(each.value.source_threat_intelligence) > 0 ? each.value.source_threat_intelligence : null
    dest_threat_intelligences = length(each.value.destination_threat_intelligence) > 0 ? each.value.destination_threat_intelligence : null
    src_network_context       = each.value.source_network_context
    dest_network_context      = each.value.destination_network_context
    src_networks              = length(each.value.source_networks) > 0 ? each.value.source_networks : null

    dynamic "src_secure_tags" {
      for_each = each.value.source_secure_tags
      content {
        name = src_secure_tags.value
      }
    }

    dynamic "layer4_configs" {
      for_each = each.value.layer4
      content {
        ip_protocol = layer4_configs.value.protocol
        ports       = layer4_configs.value.ports
      }
    }
  }

  dynamic "target_secure_tags" {
    for_each = each.value.target_secure_tags
    content {
      name = target_secure_tags.value
    }
  }
}
