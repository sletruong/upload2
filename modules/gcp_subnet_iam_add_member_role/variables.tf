variable "region" {
  description = "us-east4 is primary and us-central1 is dr"
}

variable "network_name" {
}

variable "subnetwork_name" {
}

variable "project_id" {

}

variable "iam_roles" {
  type = map(object({
    role    = string
    members = list(string)
  }))
  default = {}
}