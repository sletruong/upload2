locals {
  create_public_ip = {
    for k, v in var.network_interfaces : k => try(v.create_public_ip, false)
  }
  access_configs = {
    for k, v in var.network_interfaces : k => {
      nat_ip                 = try(v.public_ip, google_compute_address.public[k].address, null)
      public_ptr_domain_name = try(v.public_ptr_domain_name, google_compute_address.public[k].public_ptr_domain_name, null)
    }
    if can(v.public_ip) || local.create_public_ip[k]
  }
}


data "google_compute_image" "cisco" {
  count = var.custom_image == null ? 1 : 0

  name    = var.cisco_image
  project = "cisco-public"
}

resource "google_compute_address" "private" {
  for_each = { for k, v in var.network_interfaces : k => v if v.subnetwork != null }

  name         = try(each.value.private_ip_name, "${var.name}-${each.key}-private")
  address_type = "INTERNAL"
  address      = try(each.value.private_ip, null)
  project      = var.project_id
  subnetwork   = each.value.subnetwork
  region       = one(regex("^(.*)-.", var.zone))
}

resource "google_compute_address" "public" {
  for_each = { for k, v in var.network_interfaces : k => v if local.create_public_ip[k] && try(v.public_ip, null) == null }

  name         = try(each.value.public_ip_name, "${var.name}-${each.key}-public")
  address_type = "EXTERNAL"
  project      = var.project_id
  region       = one(regex("^(.*)-.", var.zone))
}

resource "google_compute_instance" "this" {
  provider = google-beta

  name                      = var.name
  zone                      = var.zone
  machine_type              = var.machine_type
  min_cpu_platform          = var.min_cpu_platform != "" ? var.min_cpu_platform : null
  deletion_protection       = var.deletion_protection
  labels                    = var.labels
  tags                      = var.tags
  metadata_startup_script   = var.metadata_startup_script
  project                   = var.project_id
  resource_policies         = var.resource_policies
  can_ip_forward            = true
  allow_stopping_for_update = true


  metadata = merge({
    serial-port-enable = true
  }, var.metadata)

  service_account {
    email  = var.service_account
    scopes = var.scopes
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces

    content {

      network_ip = try(google_compute_address.private[network_interface.key].address, null)
      subnetwork = try(network_interface.value.subnetwork, null)

      network_attachment = network_interface.value.network_attachment

      dynamic "access_config" {
        for_each = try(local.access_configs[network_interface.key] != null, false) ? ["one"] : []
        content {
          nat_ip                 = local.access_configs[network_interface.key].nat_ip
          public_ptr_domain_name = local.access_configs[network_interface.key].public_ptr_domain_name
        }
      }

      dynamic "alias_ip_range" {
        for_each = try(network_interface.value.alias_ip_ranges, [])
        content {
          ip_cidr_range         = alias_ip_ranges.value.ip_cidr_range
          subnetwork_range_name = try(alias_ip_ranges.value.subnetwork_range_name, null)
        }
      }
    }
  }

  boot_disk {
    initialize_params {
      image = coalesce(var.custom_image, try(data.google_compute_image.cisco[0].self_link, null))
      type  = var.disk_type
    }
  }
}
