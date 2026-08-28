

resource "google_compute_subnetwork_iam_binding" "members_roles" {
  project    = var.project_id
  region     = var.region
  subnetwork = var.subnetwork_name

  for_each = var.iam_roles != null ? var.iam_roles : {}
  role     = each.value["role"]
  members  = each.value["members"]
}

output "etags" {
  value = [
    for bd in google_compute_subnetwork_iam_binding.members_roles : bd.etag
  ]
}