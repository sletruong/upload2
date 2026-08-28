variable "project_id" {
  description = "Project the spoke and BGP peers are created in (the appliances' project)."
  type        = string
}

variable "name" {
  description = "Spoke name (explicit — the naming layer's contract)."
  type        = string
}

variable "region" {
  description = "Region of the transit subnet and Cloud Router. Router-appliance spokes are REGIONAL, unlike VPC spokes (location = global)."
  type        = string
}

variable "hub" {
  description = "Full hub URI (projects/<hub-project>/locations/global/hubs/<name>) — caller-constructed from the hub's RENDERED name (names-as-contract; the hub is tier-1 content in another state)."
  type        = string
}

variable "group" {
  description = "Full group URI (<hub>/groups/<token>), or null on a mesh hub which has no groups. On a star hub this is the ARCHITECTURE: `center` makes every edge spoke hairpin through this appliance."
  type        = string
  default     = null
}

variable "instances" {
  description = <<-EOT
    The appliance NICs in THIS spoke — one entry per (instance × joining NIC).

    ⚠ AN HA PAIR IS ONE SPOKE WITH TWO MEMBERS, NOT TWO SPOKES. Members of
    one spoke do NOT redistribute routes to each other and advertise with
    EQUAL MED, which is what produces priority-based failover instead of a
    flap between peers. Splitting them into two spokes breaks both.
  EOT
  type = list(object({
    name                      = string # instance short name — seeds peer names
    self_link                 = string # caller-resolved; the ordering edge to the instance
    ip_address                = string # the joining NIC's address (often NOT nic0 in these architectures)
    local_asn                 = number # the ASN THIS appliance announces (see below)
    advertised_route_priority = optional(number)
  }))

  validation {
    condition     = length(var.instances) > 0
    error_message = "An RA spoke with zero instances is not a spoke — omit the module call instead."
  }
}

variable "site_to_site_data_transfer" {
  description = "Spoke-level s2s. ⚠ ALL s2s SPOKES IN A HUB MUST SHARE ONE ROUTING VPC — the API REJECTS a second s2s VPC (verified live)."
  type        = bool
  default     = false
}

variable "include_import_ranges" {
  description = "Import filter, e.g. [\"ALL_IPV4_RANGES\"]. Empty = API default."
  type        = list(string)
  default     = []
}

variable "cloud_router" {
  description = <<-EOT
    The TIER-2 peering surface this spoke's BGP sessions bind to, or null to
    create the SPOKE ONLY (a first-class staging mode: it is how you stage an
    appliance whose adjacency an operator brings up by hand over IAP).

    ⚠ THIS MODULE DOES NOT CREATE ROUTER INTERFACES. Tier 2 owns them,
    declared on the VPC document beside the subnet CIDR they spend from.
    This module names them; creating them here would collide with tier 2 on
    the same addresses at apply rather than failing cleanly.

    ⚠ EXACTLY TWO INTERFACE NAMES. GCP requires a REDUNDANT PAIR even for a
    single appliance, and every member NIC peers with BOTH — so an HA pair
    yields FOUR sessions.
  EOT
  type = object({
    router     = string
    interfaces = list(string)
  })
  default = null

  validation {
    condition     = var.cloud_router == null || length(try(var.cloud_router.interfaces, [])) == 2
    error_message = "cloud_router.interfaces must name EXACTLY two tier-2 router interfaces — GCP rejects an unpaired router-appliance interface."
  }
}

variable "description" {
  description = "Spoke description."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Spoke labels."
  type        = map(string)
  default     = {}
}
