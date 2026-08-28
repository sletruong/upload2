variable "project_id" {
  type        = string
  description = "The PRODUCER project — where the attachment, its NAT subnets, and the published service live."
}
variable "name" {
  type        = string
  description = "Service attachment name (explicit — the naming layer's contract)."
}
variable "region" {
  type        = string
  description = "MUST equal the target service's region. Service attachments are REGIONAL; consumer endpoints connect from the same region."
}
variable "description" {
  type    = string
  default = ""
}
variable "target_service" {
  type        = string
  description = <<-EOT
    The service being published. NOT restricted to forwarding rules — the
    field is "the URL of a service serving the endpoint". For Secure Web
    Proxy this is the GATEWAY URI:
      //networkservices.googleapis.com/projects/<p>/locations/<r>/gateways/<n>
  EOT
}
variable "nat_subnets" {
  type        = list(string)
  description = <<-EOT
    Subnets with `purpose: PRIVATE_SERVICE_CONNECT`, used to NAT consumer
    traffic. ⚠ SEPARATE from the REGIONAL_MANAGED_PROXY subnet SWP itself
    needs — an estate needs BOTH, and confusing them fails at apply.
    Must be in the SAME region as the attachment and every consumer endpoint.
  EOT

  validation {
    condition     = length(var.nat_subnets) > 0
    error_message = "At least one PRIVATE_SERVICE_CONNECT subnet is required for NAT."
  }
}
variable "connection_preference" {
  type        = string
  default     = "ACCEPT_AUTOMATIC"
  description = "ACCEPT_AUTOMATIC = any consumer may connect. ACCEPT_MANUAL requires per-project allowlisting via consumer_accept_lists — a silent connection failure if forgotten."

  validation {
    condition     = contains(["ACCEPT_AUTOMATIC", "ACCEPT_MANUAL"], var.connection_preference)
    error_message = "connection_preference must be ACCEPT_AUTOMATIC or ACCEPT_MANUAL."
  }
}
variable "enable_proxy_protocol" {
  type        = bool
  default     = false
  description = "REQUIRED by the provider (not optional). Supplies client TCP/IP data to the producer; SWP does not need it, so false."
}
