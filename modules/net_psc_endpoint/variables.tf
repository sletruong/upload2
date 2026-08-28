variable "project_id" {
  type        = string
  description = "The CONSUMER project — where the endpoint and its address live. Normally NOT the producer's project."
}
variable "name" {
  type        = string
  description = "Endpoint (forwarding rule) name (explicit — the naming layer's contract)."
}
variable "region" {
  type        = string
  description = "⚠ MUST equal the service attachment's region. PSC endpoints are REGIONAL and there is no cross-region form; a mismatch fails at apply."
}
variable "network" {
  type        = string
  description = "The CONSUMER VPC self link the endpoint lives in — must contain var.subnetwork."
}
variable "subnetwork" {
  type        = string
  description = "An ORDINARY subnet in the consumer VPC — the endpoint's address comes from here. NOT a PRIVATE_SERVICE_CONNECT subnet: that purpose is for the PRODUCER's NAT subnet."
}
variable "ip_address" {
  type        = string
  default     = null
  description = <<-EOT
    Reserved internal address for the endpoint. Omit to auto-allocate.

    ⚠ PIN IT when clients hardcode the value — for Secure Web Proxy the
    endpoint IP IS the proxy URL that workloads set in HTTP_PROXY /
    HTTPS_PROXY, so an address that moves on recreate silently breaks every
    client that cached it.
  EOT
}
variable "target" {
  type        = string
  description = "The service attachment path: projects/<producer>/regions/<region>/serviceAttachments/<name>."
}
