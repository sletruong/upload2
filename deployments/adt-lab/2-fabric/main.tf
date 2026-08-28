# Thin stage root — 2-fabric for adt-lab.
# Builds all 8 VPCs, subnets, Cloud Routers (with NCC interfaces for RA spokes),
# classic firewall rules, and NCC VPC spokes.
# Apply after 1-shared; destroy before 1-shared.

locals {
  config = yamldecode(file("${path.module}/../deployment.yaml"))

  networks = flatten([
    for f in fileset("${path.module}/networks", "*.yaml") :
    yamldecode(file("${path.module}/networks/${f}"))
    if trimspace(replace(file("${path.module}/networks/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  ])
}

provider "google" {
  project = local.config.project.project_id
}

provider "google-beta" {
  project = local.config.project.project_id
}

module "fabric" {
  source = "../../../stacks/2-fabric"

  project_id      = local.config.project.project_id
  deployment_code = local.config.deployment.code
  labels          = try(local.config.deployment.labels, {})

  address_groups = {
    target = "projects/${local.config.project.project_id}"
    groups = []
  }
  secure_tags = { keys = [] }
  addresses = {
    target = "projects/${local.config.project.project_id}"
    items  = []
  }
  defaults        = try(local.config.defaults.network, {})
  subnet_defaults = try(local.config.defaults.subnetwork, null)
  networks        = local.networks
}

output "networks" {
  description = "VPCs created by this stage."
  value       = module.fabric.networks
}
