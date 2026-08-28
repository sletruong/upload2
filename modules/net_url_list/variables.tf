variable "project_id" {
  type        = string
  description = "The URL list's project."
}
variable "name" {
  type        = string
  description = "URL list name (explicit — the naming layer's contract)."
}
variable "region" {
  type        = string
  description = "REGIONAL resource. Must match the region of every SWP policy rule and gateway that references it."
}
variable "description" {
  type    = string
  default = ""
}
variable "values" {
  type        = list(string)
  description = <<-EOT
    Host/URL patterns. GCP matcher syntax, NOT regex:
      example.com          host + all subdomains + all paths
      example.com/path     that path prefix only
      *.example.com        subdomains ONLY (does NOT match the apex)

    ⚠ `*.example.com` EXCLUDES `example.com`. An allowlist written only in
    wildcard form silently drops the apex host, which is exactly where most
    vendors publish their metadata.
  EOT

  validation {
    condition     = length(var.values) > 0
    error_message = "A URL list with no values matches nothing — omit the list instead of shipping an empty one."
  }
}
