# google_logging_metric — creates the metric that an alert policy's
# `requires.metric` then references (an ordinary same-state edge).
#
# This family exists for what the metric tier structurally CANNOT do:
# route IDENTITY (every route metric is a count), config-change events,
# and per-VM NAT allocation detail.

resource "google_logging_metric" "this" {
  project          = var.project_id
  name             = var.name
  description      = var.description
  filter           = var.filter
  disabled         = !var.enabled # polarity flip owned here
  label_extractors = var.label_extractors
  value_extractor  = var.value_extractor
  bucket_name      = var.bucket_name

  dynamic "metric_descriptor" {
    for_each = var.metric_descriptor == null ? [] : [var.metric_descriptor]
    content {
      metric_kind  = metric_descriptor.value.metric_kind
      value_type   = metric_descriptor.value.value_type
      unit         = metric_descriptor.value.unit
      display_name = metric_descriptor.value.display_name

      dynamic "labels" {
        for_each = metric_descriptor.value.labels
        content {
          key         = labels.value.key
          value_type  = labels.value.value_type
          description = labels.value.description
        }
      }
    }
  }
}
