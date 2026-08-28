variable "project_id" {
  type        = string
  description = "The gateway's project."
}
variable "name" {
  type        = string
  description = "Gateway name (explicit — the naming layer's contract)."
}
variable "region" {
  type        = string
  description = "REGIONAL resource. The VIP subnet, the REGIONAL_MANAGED_PROXY subnet, and the attached policy must all be in this region."
}
variable "description" {
  type    = string
  default = ""
}
variable "network" {
  type        = string
  description = "The VPC the proxy VIP lives IN. ⚠ THIS IS THE REACHABILITY BOUNDARY — see main.tf."
}
variable "subnetwork" {
  type        = string
  description = "Subnet the VIP is allocated from. NOT the proxy-only subnet: SWP additionally requires a REGIONAL_MANAGED_PROXY subnet to exist in this VPC+region, which it finds itself."
}
variable "addresses" {
  type        = list(string)
  default     = []
  description = "Zero or one address. Omit = allocated from the subnet, which makes the VIP UNSTABLE across recreate — pin it when clients hardcode a proxy URL."
}
variable "ports" {
  type    = list(number)
  default = [443]
}
variable "gateway_security_policy" {
  type        = string
  default     = null
  description = "Policy path. Omit = NO policy = the proxy allows nothing useful; it is not a permissive default."
}
variable "certificate_urls" {
  type        = list(string)
  default     = []
  description = "Certificate Manager cert URLs. REQUIRED in practice for HTTPS interception — clients see this cert, not the origin's."
}
variable "scope" {
  type        = string
  default     = null
  description = "Gateways sharing a scope MERGE into one proxy config. Two gateways sharing a scope by accident is a silent config merge."
}
variable "labels" {
  type    = map(string)
  default = {}
}
