variable "project_id" {
  description = "The ID of the project where this NCC Hub will be created"
  type        = string
}

variable "ncc_hubs" {
  description = "Map of NCC Hub configurations."
  type = map(object({
    ncc_hub_name = string
    description  = optional(string, "")
  }))
}
