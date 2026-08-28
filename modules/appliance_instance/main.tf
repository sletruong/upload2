/**
 * Appliance instance — a multi-NIC forwarding VM (stage 5-appliance).
 * can_ip_forward is hardcoded TRUE: an appliance that can't forward is a
 * contradiction, and flipping it forces instance replacement — not a knob.
 * NIC position is the GCP index (physical form; dynamic sub-interfaces are
 * RESERVED with the RA family). Bootstrap stays out of this surface —
 * vendor config lands over IAP SSH; metadata passes through untyped for a
 * later cloud-init story.
 */

locals {
  region = join("-", slice(split("-", var.zone), 0, 2))
}

resource "google_compute_instance" "this" {
  project                   = var.project_id
  name                      = var.name
  zone                      = var.zone
  machine_type              = var.machine_type
  min_cpu_platform          = var.min_cpu_platform
  can_ip_forward            = true
  tags                      = var.network_tags
  allow_stopping_for_update = true

  # ⚠ VENDOR DAY-0, PASSED THROUGH UNINTERPRETED. PAN-OS reads init-cfg
  # keys straight off instance metadata (no GCS bootstrap bucket needed
  # for the basic case); cloud-init images read `user-data`. GCE accepts
  # ANY key, so a misspelled one is silently ignored by the guest — the
  # instance boots healthy and simply is not configured.
  metadata = length(var.metadata) > 0 ? var.metadata : null

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  # ⚠ FORTIGATE REQUIRES AN SA (measured, serial-confirmed): the vendor's
  # boot-time instance-identity check needs the metadata identity endpoint,
  # which only exists when an SA is attached — without one the box logs
  # "GCP instance check failed" and self-terminates ~2 min in. Other vendors
  # boot fine without; null omits the block entirely (no SA attached).
  dynamic "service_account" {
    for_each = var.service_account_email == null ? [] : [var.service_account_email]
    content {
      email  = service_account.value
      scopes = ["cloud-platform"]
    }
  }

  # ⚠ SPOT IS THREE COORDINATED FIELDS, NOT ONE. provisioning_model alone
  # is rejected: the API requires preemptible=true and automatic_restart=
  # false alongside it. Setting only provisioning_model="SPOT" fails at
  # apply with a validation error, and setting preemptible without the
  # model silently gets you the LEGACY preemptible class (24h cap) rather
  # than Spot.
  #
  # ⚠ instance_termination_action IS REQUIRED FOR SPOT AND HAS NO SAFE
  # DEFAULT HERE. STOP keeps the boot disk and its guest config, so a
  # preempted appliance can be restarted with its hand-applied VyOS/PAN-OS
  # config intact. DELETE would destroy it and force a full rebuild —
  # catastrophic for a box whose config is not in Terraform.
  #
  # ⚠ CHANGING THIS FIELD FORCES INSTANCE REPLACEMENT. Flipping spot on or
  # off on a deployed appliance destroys and recreates it, which for a
  # hand-configured box means re-entering the guest config. Decide before
  # the first apply.
  dynamic "scheduling" {
    for_each = var.spot ? [1] : []
    content {
      provisioning_model          = "SPOT"
      preemptible                 = true
      automatic_restart           = false
      instance_termination_action = "STOP"
    }
  }

  # ⚠ TWO NIC FORMS. An ordinary NIC names a subnet in THIS project. A PSC
  # INTERFACE names a network attachment in ANOTHER project and carries no
  # subnetwork at all — its address is allocated from the consumer's subnet.
  # Building the subnetwork path unconditionally would send a bogus path for
  # a PSC NIC, so both are nulled per-form rather than always constructed.
  dynamic "network_interface" {
    for_each = var.nics
    content {
      subnetwork = try(network_interface.value.network_attachment, null) != null ? null : "projects/${var.project_id}/regions/${local.region}/subnetworks/${network_interface.value.subnetwork}"

      # ⚠ EXPLICIT ON THE SUBNET FORM — the PSC→subnet REVERT direction needs
      # it (verified live): with it unset, the provider's plan-time diff
      # carries the STALE subnetwork_project from the attachment state (the
      # consumer's project) against the new subnet self_link and rejects the
      # plan ("must match subnetwork_project") before force-new is decided.
      subnetwork_project = try(network_interface.value.network_attachment, null) != null ? null : var.project_id

      # ⚠ A PROJECT ID IN THIS PATH IS SAFE — MEASURED. The provider docs
      # specify projects/{projectNumber}/..., but the provider NORMALIZES: a
      # project ID produced no perma-diff across apply and re-plan. No
      # ID->number resolution is needed.
      network_attachment = try(network_interface.value.network_attachment, null)

      network_ip = try(network_interface.value.network_attachment, null) != null ? null : network_interface.value.private_address

      dynamic "access_config" {
        # ⚠ NO EXTERNAL ADDRESS ON A PSC INTERFACE, EVER (GCP law).
        for_each = try(network_interface.value.network_attachment, null) == null && network_interface.value.external ? [1] : []
        content {}
      }
    }
  }
}
