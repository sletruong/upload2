# VPC peering (fabric): ONE SIDE per resource. The stack fans a PAIR
# declaration into two instances of this module; one-sided instances serve
# external partners who own their own half.
# The time_sleep spaces peering operations to dodge the provider bug around
# creating too many too fast (hashicorp/terraform-provider-google#3034).

resource "time_sleep" "pacing" {
  create_duration = "5s"
}

resource "google_compute_network_peering" "peering" {
  depends_on = [time_sleep.pacing]

  name         = var.name
  network      = var.network
  peer_network = var.peer_network

  export_custom_routes                = var.export_custom_routes
  import_custom_routes                = var.import_custom_routes
  export_subnet_routes_with_public_ip = var.export_subnet_routes_with_public_ip
  import_subnet_routes_with_public_ip = var.import_subnet_routes_with_public_ip

  stack_type = var.stack_type
}
