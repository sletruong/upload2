# Thin stage root — 5-appliance for adt-lab.
# Builds: Cisco C8000v (RA spokes) + Palo Alto VM-Series (NSI intercept)
# across us-central1, us-east4, us-west2 (zones a+b per region).
# NSI ILBs cover zones a+b+c; zone-c ILBs are memberless but reserve the VIP.
# Apply after 2-fabric; destroy before 2-fabric.

variable "cisco_admin_password" {
  description = "Cisco C8000v admin password. Set in secret.auto.tfvars (gitignored — never commit this value)."
  type        = string
  sensitive   = true
}

locals {
  config = yamldecode(file("${path.module}/../deployment.yaml"))

  appliance_docs_raw = flatten([
    for f in fileset("${path.module}/appliances", "*.yaml") :
    yamldecode(file("${path.module}/appliances/${f}"))
    if trimspace(replace(file("${path.module}/appliances/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  ])

  # Cisco password injected here so it never lives in YAML files.
  # Palo Alto admin password is intentionally omitted — set post-boot via console.
  appliance_docs = [
    for a in local.appliance_docs_raw :
    merge(a, {
      bootstrap = merge(try(a.bootstrap, {}), {
        cisco = merge(try(a.bootstrap.cisco, {}), {
          config_lines = a.vendor == "cisco" ? concat(
            ["username admin secret 0 ${var.cisco_admin_password}"],
            try(a.bootstrap.cisco.config_lines, [])
          ) : try(a.bootstrap.cisco.config_lines, [])
        })
      })
    })
  ]

  ilb_docs = flatten([
    for f in fileset("${path.module}/ilbs", "*.yaml") :
    yamldecode(file("${path.module}/ilbs/${f}"))
    if trimspace(replace(file("${path.module}/ilbs/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  ])

  spoke_docs = flatten([
    for f in fileset("${path.module}/spokes", "*.yaml") :
    yamldecode(file("${path.module}/spokes/${f}"))
    if trimspace(replace(file("${path.module}/spokes/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  ])

  nsi_docs = {
    for fam in ["deployment_groups", "endpoint_groups"] : fam => flatten([
      for f in fileset("${path.module}/nsi/${fam}", "*.yaml") :
      yamldecode(file("${path.module}/nsi/${fam}/${f}"))
      if trimspace(replace(file("${path.module}/nsi/${fam}/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
    ])
  }

  ssh_key_docs = flatten([
    for f in fileset("${path.module}/ssh_keys", "*.yaml") :
    yamldecode(file("${path.module}/ssh_keys/${f}"))
    if trimspace(replace(file("${path.module}/ssh_keys/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  ])
}

provider "google" {
  project               = local.config.project.project_id
  user_project_override = true
  billing_project       = local.config.project.project_id
}

provider "google-beta" {
  project               = local.config.project.project_id
  user_project_override = true
  billing_project       = local.config.project.project_id
}

module "appliance" {
  source = "../../../stacks/5-appliance"

  deployment_code       = local.config.deployment.code
  appliances            = local.appliance_docs
  ssh_keys              = local.ssh_key_docs
  spokes                = local.spoke_docs
  ilbs                  = local.ilb_docs
  routes                = []
  nsi_deployment_groups = local.nsi_docs["deployment_groups"]
  nsi_endpoint_groups   = local.nsi_docs["endpoint_groups"]

  # Defer module data-source reads (ssh_key mode=reference) until after the
  # Secret Manager versions created in keys_upload.tf are applied.
  depends_on = [
    google_secret_manager_secret_version.cisco_ssh_key,
    google_secret_manager_secret_version.palo_ssh_key,
  ]
}

output "appliances" {
  description = "Cisco and Palo Alto fleet: per-NIC addresses."
  value       = module.appliance.appliances
}

output "ilbs" {
  description = "NSI GENEVE ILB frontends: VIP, forwarding rule."
  value       = module.appliance.ilbs
}

output "nsi" {
  description = "NSI intercept chain: deployment group, zonal deployments, endpoint group."
  value       = module.appliance.nsi
}
