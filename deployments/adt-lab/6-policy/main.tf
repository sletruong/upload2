# Thin stage root — tier 6: the env's ONE security-policy state.
#
# WHY THIS STAGE EXISTS — THE §4c DESTROY-WEDGE: if the SPG and the GNFP
# rules that name it live in different Terraform states, GCP rejects SPG
# deletion while rules still reference it (Error 400 "already being used").
# At tier 6 both are in ONE state: the rule->SPG edge is intra-state, so
# destroy runs 6-first and the wedge cannot occur BY SHAPE.
#
# Apply order: 1-shared -> 2-fabric -> 5-appliance -> 6-policy
# Destroy order: 6-policy -> 5-appliance -> 2-fabric -> 1-shared
#
# Cross-state references into tier 5:
#   - endpoint_group names in SPG docs are {explicit:} into tier-5 resources.
#     Plan-time-existence-blind BY DESIGN; stage order 5-before-6 is the
#     existence guarantee. A wrong name is GCP's 404 at apply, not a plan error.
#
# Two global policies:
#   adt-lab-wan-policy      — wan1-vpc1, wan2-vpc1, lan-transit-vpc1
#                             Rules: east-west Cisco inspection (ewti SPG, Palo NIC1)
#   adt-lab-workload-policy — lan-workload-vpc1
#                             Rules: RFC1918 → interzone inspection (ieti, Palo NIC4)
#                                    internet → north-south inspection (nsti, Palo NIC2)
#
# ⚠ lan-mgmt-vpc is DELIBERATELY ABSENT from both policies. Binding the
# management plane VPC would route admin SSH through the Palo fleet; a fleet
# outage would make the boxes unreachable — the exact lockout out-of-band
# management exists to prevent.

locals {
  config = yamldecode(file("${path.module}/../deployment.yaml"))

  fp_global_docs = {
    for f in fileset("${path.module}/firewall_policies/global", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/firewall_policies/global/${f}"))
    if trimspace(replace(file("${path.module}/firewall_policies/global/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  }

  spg_docs = flatten([
    for f in fileset("${path.module}/security_profile_groups", "*.yaml") :
    yamldecode(file("${path.module}/security_profile_groups/${f}"))
    if trimspace(replace(file("${path.module}/security_profile_groups/${f}"), "/(?m)^[ \t]*#.*/", "")) != ""
  ])
}

# ⚠ user_project_override = true IS REQUIRED for org-scoped security profiles.
# Without it the provider omits the X-Goog-User-Project header and the API
# returns 403. This also fails the whole stage (profile is early in the graph).
provider "google" {
  project               = local.config.project.project_id
  user_project_override = true
  billing_project       = local.config.project.project_id
}

module "policy" {
  source = "../../../stacks/6-policy"

  project_id      = local.config.project.project_id
  deployment_code = local.config.deployment.code
  labels          = try(local.config.deployment.labels, {})

  firewall_policies = {
    global = [
      for name, doc in local.fp_global_docs : {
        mode        = doc.mode
        name        = doc.name
        description = try(doc.description, "")
        project_id  = try(doc.project_id, null)
        networks    = try(doc.networks, [])
        folder_path = "${path.module}/firewall_policies/global/${name}.rules"
      }
    ]
    regional = []
  }

  security_profile_groups = {
    target = "projects/${local.config.project.project_id}"
    groups = local.spg_docs
  }
}

output "firewall_policies" {
  description = "Global network firewall policies — wan and workload inspection."
  value       = module.policy.firewall_policies
}

output "firewall_policy_attachments" {
  description = "networks[]-emitted associations. VPCs absent here (mgmt) are outside the policy entirely."
  value       = module.policy.firewall_policy_attachments
}

output "security_profile_groups" {
  description = "NSI INTERCEPT SPGs — ewti, nsti, izti, ieti."
  value       = module.policy.security_profile_groups
}
