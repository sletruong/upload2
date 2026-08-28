# Thin stage root — 1-shared for adt-lab.
# Creates the three NCC hubs that Cisco RA spokes and VPC spokes join.
# Apply before 2-fabric and 5-appliance; destroy last.

locals {
  config = yamldecode(file("${path.module}/../deployment.yaml"))

  ncc_hubs = flatten([
    for f in fileset("${path.module}/ncc_hubs", "*.yaml") :
    yamldecode(file("${path.module}/ncc_hubs/${f}"))
    if trimspace(replace(file("${path.module}/ncc_hubs/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  ])

  secure_tag_docs = flatten([
    for f in fileset("${path.module}/secure_tags", "*.yaml") :
    yamldecode(file("${path.module}/secure_tags/${f}"))
    if trimspace(replace(file("${path.module}/secure_tags/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  ])
}

provider "google" {
  project               = local.config.project.project_id
  user_project_override = true
  billing_project       = local.config.project.project_id
}

module "shared" {
  source = "../../../stacks/1-shared"

  deployment_code = local.config.deployment.code
  labels          = try(local.config.deployment.labels, {})
  ncc_hubs        = local.ncc_hubs
  address_groups = {
    target = "projects/${local.config.project.project_id}"
    groups = []
  }
  secure_tags = {
    target = "projects/${local.config.project.project_id}"
    keys   = local.secure_tag_docs
  }
}

output "ncc_hubs" {
  description = "NCC hubs created (spokes join by hub name in 2-fabric / 5-appliance)."
  value       = module.shared.ncc_hubs
}

output "secure_tags" {
  description = "Secure tag value IDs: key/value -> tagValues/N. Copy these into 6-policy rule target_secure_tags as {resolved: <value>}."
  value       = module.shared.secure_tags
}
