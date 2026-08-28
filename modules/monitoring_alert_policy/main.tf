# google_monitoring_alert_policy — one policy per (document, severity band).
#
# PROVIDER SHAPE (verified against `terraform providers schema` google 7.x
# and the Monitoring v3 discovery doc):
#   - `severity` and `notification_channels` are POLICY-level, not
#     condition-level. That is WHY a warn/critical pair must be two
#     policies — one policy cannot route two severities to two channels.
#   - `conditions` is a LIST, but a `combiner` is required whenever more
#     than one exists. We emit exactly ONE condition per policy and pin
#     combiner = "OR" so the field is never load-bearing.
#   - `condition_threshold.duration` is REQUIRED; `threshold_value` is not
#     (absent means 0, which is what a BOOL/GT-0 condition wants).
#   - `denominator_filter` makes ratio conditions NATIVE — MQL is not
#     needed for ratios.
#
# The DOCUMENT says what the architecture requires; this module owns the
# provider's encoding. No document ever writes COMPARISON_GT or REDUCE_SUM.

locals {
  # Provider wants uppercase severity; documents say lowercase.
  severity = var.severity == null ? null : upper(var.severity)
}

resource "google_monitoring_alert_policy" "this" {
  project      = var.project_id
  display_name = var.name
  combiner     = "OR" # exactly one condition per policy — see header
  enabled      = var.enabled
  severity     = local.severity

  notification_channels = var.notification_channels
  user_labels           = var.user_labels

  dynamic "documentation" {
    for_each = var.description == "" ? [] : [1]
    content {
      content   = var.description
      mime_type = "text/markdown"
    }
  }

  dynamic "alert_strategy" {
    for_each = var.auto_close == null && var.renotify_interval == null ? [] : [1]
    content {
      auto_close = var.auto_close
      dynamic "notification_channel_strategy" {
        for_each = var.renotify_interval == null ? [] : [1]
        content {
          renotify_interval = var.renotify_interval
        }
      }
    }
  }

  # ── THRESHOLD ──────────────────────────────────────────────────────────
  dynamic "conditions" {
    for_each = var.threshold == null ? [] : [var.threshold]
    content {
      display_name = var.name
      condition_threshold {
        filter          = conditions.value.filter
        comparison      = conditions.value.comparison
        threshold_value = conditions.value.threshold_value
        duration        = conditions.value.duration

        # A missing series must NOT read as "healthy". The absence
        # companion is the real detector, but this stops a gap in the
        # data from silently resolving an open incident.
        evaluation_missing_data = "EVALUATION_MISSING_DATA_NO_OP"

        aggregations {
          alignment_period     = conditions.value.alignment_period
          per_series_aligner   = conditions.value.per_series_aligner
          cross_series_reducer = conditions.value.cross_series_reducer
          group_by_fields      = conditions.value.group_by_fields
        }

        denominator_filter = conditions.value.denominator_filter

        dynamic "denominator_aggregations" {
          for_each = conditions.value.denominator_filter == null ? [] : [1]
          content {
            alignment_period     = conditions.value.alignment_period
            per_series_aligner   = conditions.value.denominator_aligner
            cross_series_reducer = conditions.value.denominator_reducer
            group_by_fields      = conditions.value.group_by_fields
          }
        }
      }
    }
  }

  # ── ABSENCE ────────────────────────────────────────────────────────────
  dynamic "conditions" {
    for_each = var.absent == null ? [] : [var.absent]
    content {
      display_name = var.name
      condition_absent {
        filter   = conditions.value.filter
        duration = conditions.value.duration
        aggregations {
          alignment_period     = conditions.value.alignment_period
          per_series_aligner   = conditions.value.per_series_aligner
          cross_series_reducer = conditions.value.cross_series_reducer
          group_by_fields      = conditions.value.group_by_fields
        }
      }
    }
  }

  # ── LOG MATCH ──────────────────────────────────────────────────────────
  dynamic "conditions" {
    for_each = var.log_match == null ? [] : [var.log_match]
    content {
      display_name = var.name
      condition_matched_log {
        filter           = conditions.value.filter
        label_extractors = conditions.value.label_extractors
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length([for c in [var.threshold, var.absent, var.log_match] : c if c != null]) == 1
      error_message = "Exactly ONE condition kind per policy (threshold XOR absent XOR log_match): ${var.name}"
    }
  }
}
