output "key_id" {
  description = "tagKeys/N."
  value       = google_tags_tag_key.key.id
}

output "value_ids" {
  description = "value short_name => tagValues/N — the rule-reference resolution surface."
  value       = { for k, v in google_tags_tag_value.value : k => v.id }
}
