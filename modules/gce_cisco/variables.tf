variable "name" {
  description = "Name of the cisco router"
  type        = string
}

variable "project_id" {
  description = "The ID of the project where the routes will be created"
  type        = string
}


variable "zone" {
  description = "zone where the cisco router is deployed"
  type        = string
}

variable "machine_type" {
  description = "Cisco router instance machine type, which depends on the license used. See the [Terraform manual](https://www.terraform.io/docs/providers/google/r/compute_instance.html)"
  default     = "n2-standard-4"
  type        = string
}

variable "cisco_image" {
  description = <<EOF
  The image name from which to boot an instance, including the license type and the version.
  To get a list of available official images, please run the following command:
  `gcloud compute images list --filter="name ~ cisco" --project cisco-public --no-standard-images`
  EOF
  default     = "cisco-c8k-17-14-01a"
  type        = string
}

variable "custom_image" {
  description = "The full URI to GCE image resource, the output of `gcloud compute images list --uri`. Overrides official image specified using `cisco_image`."
  default     = "https://www.googleapis.com/compute/v1/projects/cisco-public/global/images/cisco-c8k-17-14-01a"
  type        = string
}

variable "service_account" {
  description = "IAM Service Account for running router instance (just the email)"
  type        = string
}

variable "network_interfaces" {
  description = <<-EOF
  List of the network interface specifications.
  Available options:
  - `subnetwork`             - (Required|string) Self-link of a subnetwork to create interface in.
  - `private_ip_name`        - (Optional|string) Name for a private address to reserve.
  - `private_ip`             - (Optional|string) Private address to reserve.
  - `create_public_ip`       - (Optional|boolean) Whether to reserve public IP for the interface. Ignored if `public_ip` is provided. Defaults to 'false'.
  - `public_ip_name`         - (Optional|string) Name for a public address to reserve.
  - `public_ip`              - (Optional|string) Existing public IP to use.
  - `public_ptr_domain_name` - (Optional|string) Existing public PTR name to use.
  - `network_attachment`     - (Optional|string) Self-Link to a Private Service Connection network attachment.
  - `alias_ip_ranges`        - (Optional|list) List of objects that define additional IP ranges for an interface, as specified [here](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#ip_cidr_range)
  EOF
  type        = list(any)
}

#variable "bootstrap_file" {
#  description = "File name of the bootstrap in current directory"
#  type        = string
#}

variable "metadata" {
  description = "Other, not VM-Series specific, metadata to set for an instance."
  default     = {}
  type        = map(string)
}

variable "metadata_startup_script" {
  description = "See the [Terraform manual](https://www.terraform.io/docs/providers/google/r/compute_instance.html)"
  default     = null
  type        = string
}

variable "scopes" {
  default = [
    "https://www.googleapis.com/auth/compute.readonly",
    "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
  ]
  type = list(string)
}

variable "min_cpu_platform" {
  description = "Minimum CPU platform for the compute instance. Up to date version can be found [here](https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform). Leave empty for GCP to select automatically (required for AMD machine families like n4d)."
  default     = ""
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection on the instance."
  default     = false
  type        = bool
}

variable "disk_type" {
  description = "Boot disk type. See [provider documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#type) for available values."
  default     = "pd-standard"
}

variable "labels" {
  description = "GCP instance lables."
  default     = {}
  type        = map(any)
}

variable "tags" {
  description = "GCP instance tags."
  default     = []
  type        = list(string)
}

variable "resource_policies" {
  default = []
  type    = list(string)
}
