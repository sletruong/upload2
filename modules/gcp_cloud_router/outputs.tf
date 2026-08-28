output "router_id" {
  value = { for k, v in google_compute_router.router : k => v.id }
}

output "router_self_link" {
  value = { for k, v in google_compute_router.router : k => v.self_link }
}

output "router_name" {
  value = { for k, v in google_compute_router.router : k => v.name }
}

output "cloud_nat" {
  value = { for k, v in module.cloud_nat : k => v.name }
}