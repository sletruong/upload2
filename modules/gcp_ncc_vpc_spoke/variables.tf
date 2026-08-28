variable "project_id" {
  description = "The project ID where the resources will be created"
  type        = string
}

variable "hub_name" {
  description = "Full resource name or ID of the NCC hub"
  type        = string
}

variable "spoke_name" {
  description = "Name for the VPC spoke"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network to attach as a spoke"
  type        = string
}

variable "exclude_export_ranges" {
  description = "IP CIDR ranges to exclude from export"
  type        = list(string)
  default     = []
}
