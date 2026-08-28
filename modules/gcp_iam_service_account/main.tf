# terraform {
#   required_providers {
#     google = { version = "~> 4.72.0" }
#   }
# }


locals {
  merged_roles = distinct(concat(
    var.default_roles,
    var.roles
  ))

}

resource "google_service_account" "this" {
  project      = var.project_id
  account_id = var.service_account_id
  display_name = var.display_name
}

resource "google_project_iam_member" "this" {
  for_each = toset(local.merged_roles)
  
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.this.email}"
}
