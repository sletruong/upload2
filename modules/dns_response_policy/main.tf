# Response policy (RPZ): the policy carries identity + network binding
# (cold half); rules are child resources (hot half — merged by the stack
# from sibling .rules/ docs). GCP law: max ONE response policy per network.
# Per-rule XOR: local_data (payload) or behavior: bypass (explicit field,
# rendered to the wire enum).
# Two facts, both verified live: `behavior` is GOOGLE-BETA-ONLY in provider
# 7.x (rule resource rides beta; policy stays GA), AND the wire enum is
# `bypassResponsePolicy` — NOT `bypassResponseForwarding`, which is what
# the gcloud FLAG and the concept docs call it. The API rejected the gcloud
# spelling with a fieldViolation; the Terraform provider documentation
# carries the real enum. Two names, one behavior — see `.claude/LEXICON.md`.

variable "project_id" {
  description = "The policy's project."
  type        = string
}
variable "name" {
  description = "Response policy name (explicit — the naming layer's contract)."
  type        = string
}
variable "description" {
  type    = string
  default = ""
}
variable "networks" {
  description = "RESOLVED network self-link URLs."
  type        = list(string)
}
variable "rules" {
  description = "RPZ rules (hot half — merged by the stack from sibling .rules/ docs). Per rule: local_data (payload) XOR behavior: bypass."
  type = list(object({
    name     = string
    dns_name = string
    behavior = optional(string) # bypass
    local_data = optional(object({
      records = list(object({
        name   = string
        type   = string
        ttl    = optional(number, 300)
        values = list(string)
      }))
    }))
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.rules : (r.behavior != null) != (r.local_data != null)])
    error_message = "Each rule carries exactly one of behavior: bypass XOR local_data — never both, never neither."
  }

  validation {
    condition     = alltrue([for r in var.rules : r.behavior == null || r.behavior == "bypass"])
    error_message = "behavior supports only: bypass."
  }
}

resource "google_dns_response_policy" "policy" {
  project              = var.project_id
  response_policy_name = var.name
  description          = var.description

  dynamic "networks" {
    for_each = var.networks
    content {
      network_url = networks.value
    }
  }
}

resource "google_dns_response_policy_rule" "rule" {
  provider = google-beta
  for_each = { for r in var.rules : r.name => r }

  project         = var.project_id
  response_policy = google_dns_response_policy.policy.response_policy_name
  rule_name       = each.value.name
  dns_name        = each.value.dns_name

  behavior = each.value.behavior == "bypass" ? "bypassResponsePolicy" : null

  dynamic "local_data" {
    for_each = each.value.local_data == null ? [] : [each.value.local_data]
    content {
      dynamic "local_datas" {
        for_each = local_data.value.records
        content {
          name    = local_datas.value.name
          type    = local_datas.value.type
          ttl     = local_datas.value.ttl
          rrdatas = local_datas.value.values
        }
      }
    }
  }
}
