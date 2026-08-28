# google_monitoring_notification_channel — the ACTION half of every rollup.
#
# Documents say `enabled`; the provider agrees here (unlike firewall rules,
# which say `disabled`) so there is no polarity flip to own.

resource "google_monitoring_notification_channel" "this" {
  project      = var.project_id
  display_name = var.name
  description  = var.description
  type         = var.type
  enabled      = var.enabled
  labels       = var.labels
  user_labels  = var.user_labels

  dynamic "sensitive_labels" {
    for_each = var.sensitive_labels == null ? [] : [var.sensitive_labels]
    content {
      auth_token  = sensitive_labels.value.auth_token
      password    = sensitive_labels.value.password
      service_key = sensitive_labels.value.service_key
    }
  }
}
