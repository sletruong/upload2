output "summary" {
  description = "Quota preference summary. granted_value and reconciling are the fields that matter: a successful apply means the REQUEST was accepted, not that the limit moved. Compare granted_value to preferred_value before treating headroom as real."
  value = {
    id              = google_cloud_quotas_quota_preference.preference.id
    name            = google_cloud_quotas_quota_preference.preference.name
    service         = google_cloud_quotas_quota_preference.preference.service
    quota_id        = google_cloud_quotas_quota_preference.preference.quota_id
    dimensions      = google_cloud_quotas_quota_preference.preference.dimensions
    preferred_value = var.preferred_value
    # The API returns these as STRINGS; tonumber() keeps the output comparable
    # to preferred_value so `granted < preferred` is a numeric test, not a
    # lexical one ("90" > "100" as strings).
    granted_value = try(tonumber(one(google_cloud_quotas_quota_preference.preference.quota_config[*].granted_value)), null)
    state_detail  = one(google_cloud_quotas_quota_preference.preference.quota_config[*].state_detail)
    # trace_id is produced only for INCREASE requests and is what Cloud Support
    # asks for when you chase a stalled ask.
    trace_id    = one(google_cloud_quotas_quota_preference.preference.quota_config[*].trace_id)
    reconciling = google_cloud_quotas_quota_preference.preference.reconciling
  }
}

output "granted_value" {
  description = "The limit Google actually granted. May lag preferred_value while reconciling, or settle lower if the ask was partially approved. Numeric (the API returns a string)."
  value       = try(tonumber(one(google_cloud_quotas_quota_preference.preference.quota_config[*].granted_value)), null)
}

output "reconciling" {
  description = "True while the request is pending Google approval/fulfillment. True is NOT a failure — it means the ask is in flight."
  value       = google_cloud_quotas_quota_preference.preference.reconciling
}
