# FABRIC-stage firewall policy management plane:
#   mode = "create" -> a NEW global/regional network policy born in this stage
#                      (EXPLICIT name, full priority space). Hierarchical
#                      creation stays tier-0 (org/folder governance).
#   mode = "update" -> standalone rule resources attached to an EXISTING
#                      tier-0 policy: global/regional by rendered NAME,
#                      hierarchical by NUMERIC id (GCP generates it; there is
#                      no name lookup). Priority = ENFORCEMENT ORDER in both
#                      modes; bands are RETIRED
#                      (design_and_backlog/DESIGN-DOCTRINE.md §4d).
# Rules may reference this stage's VPCs (source/target networks) — the caller
# resolves names to self links, and that reference orders VPC-before-rule on
# create and rule-before-VPC on destroy (kills the cross-stage race where the
# API rejects rules whose networks do not exist yet).

locals {
  create_global   = var.mode == "create" && var.type == "global"
  create_regional = var.mode == "create" && var.type == "regional"

  # update: attach to the existing policy; create: attach to the one born here
  # (the resource reference also gives rules their create/destroy ordering)
  global_policy   = local.create_global ? google_compute_network_firewall_policy.created[0].name : var.policy
  regional_policy = local.create_regional ? google_compute_region_network_firewall_policy.created[0].name : var.policy
}

resource "google_compute_network_firewall_policy" "created" {
  count = local.create_global ? 1 : 0

  project     = var.project_id
  name        = var.policy
  description = var.description
}

resource "google_compute_region_network_firewall_policy" "created" {
  count = local.create_regional ? 1 : 0

  project     = var.project_id
  name        = var.policy
  description = var.description
  region      = var.region
}

resource "google_compute_firewall_policy_rule" "hierarchical" {
  for_each = var.type == "hierarchical" ? var.rules : {}

  firewall_policy         = var.policy
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

  dynamic "target_secure_tags" {
    for_each = each.value.target_secure_tags
    content {
      name = target_secure_tags.value
    }
  }

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
}

resource "google_compute_network_firewall_policy_rule" "global" {
  for_each = var.type == "global" ? var.rules : {}

  project                 = var.project_id
  firewall_policy         = local.global_policy
  priority                = each.value.priority
  description             = each.value.description
  direction               = each.value.direction
  action                  = each.value.action
  enable_logging          = each.value.logging
  disabled                = !each.value.enabled # lexicon owns the polarity flip
  security_profile_group  = each.value.security_profile_group
  tls_inspect             = each.value.tls_inspect ? true : null
  target_service_accounts = length(each.value.target_service_accounts) > 0 ? each.value.target_service_accounts : null

  dynamic "target_secure_tags" {
    for_each = each.value.target_secure_tags
    content {
      name = target_secure_tags.value
    }
  }

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
}

resource "google_compute_region_network_firewall_policy_rule" "regional" {
  for_each = var.type == "regional" ? var.rules : {}

  project                 = var.project_id
  region                  = var.region
  firewall_policy         = local.regional_policy
  priority                = each.value.priority
  description             = each.value.description
  direction               = each.value.direction
  action                  = each.value.action
  enable_logging          = each.value.logging
  disabled                = !each.value.enabled # lexicon owns the polarity flip
  target_service_accounts = length(each.value.target_service_accounts) > 0 ? each.value.target_service_accounts : null

  dynamic "target_secure_tags" {
    for_each = each.value.target_secure_tags
    content {
      name = target_secure_tags.value
    }
  }

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
}
