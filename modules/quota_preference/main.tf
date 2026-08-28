/**
 * quota_preference — request a quota increase as code.
 *
 * MECHANISM (provider-verified, not inferred):
 *   google_cloud_quotas_quota_preference REQUESTS a preferred value. It is the
 *   ONLY resource that can RAISE a quota. Its sibling,
 *   google_service_usage_consumer_quota_override, can only LOWER — the docs are
 *   explicit: "Consumer overrides cannot be used to grant more quota than would
 *   be allowed by admin overrides, producer overrides, or the default limit."
 *   So increases go through quota preferences; overrides are a self-throttle.
 *
 * THE ASYNCHRONY THAT SURPRISES PEOPLE:
 *   A quota preference is a REQUEST, not a setting. apply() succeeding means
 *   Google ACCEPTED the request, not that the quota moved. `reconciling: true`
 *   and `granted_value` < `preferred_value` are both normal post-apply states.
 *   Large asks route to human review and can sit for days. This is ACTIVE !=
 *   dataplane in quota form — never gate a deployment on the apply alone; read
 *   granted_value back (outputs.tf surfaces it).
 *
 * FIXED QUOTAS: a quota with isFixed=true is not self-serve adjustable. The
 * caller is expected to filter those out (the stack does, via the catalog) —
 * this module refuses them at plan time rather than failing at apply.
 *
 * PROVIDER SHAPE (verified against `terraform providers schema`, google 7.x —
 * the published docs describe the BETA resource and disagree on all three):
 *   - `deletion_policy` does NOT exist in GA (it is a beta-only field). Destroy
 *     therefore DELETES the preference, which hands granted quota back — a
 *     production-affecting side effect when a shared landing zone is torn down.
 *     There is no in-resource mitigation available: `prevent_destroy` accepts
 *     only literals, so it cannot be driven per-instance from a document. The
 *     honest control is procedural — quota documents live in tier 0, which the
 *     runner destroys LAST, and `terraform state rm` is the escape hatch when a
 *     stack must be torn down while keeping granted quota. Tracked as a schema
 *     debt: revisit if/when deletion_policy reaches GA.
 *   - `ignore_safety_checks` is a scalar string, not a list.
 *   - `preferred_value` / `granted_value` are STRINGS, not numbers.
 */

locals {
  # Cloud Quotas is global-only; the dimension map, not the resource location,
  # scopes a preference to a region/network/hub.
  parent = "projects/${var.project_id}"

  # Deterministic default name matching Google's own convention:
  # <service with dots as underscores>-<quota_id>[-<sorted dimension values>].
  # Stable across plans (dimensions are sorted) so no spurious re-creates.
  dimension_suffix = length(var.dimensions) > 0 ? "-${join("-", [for k in sort(keys(var.dimensions)) : var.dimensions[k]])}" : ""
  default_name     = "${replace(var.service, ".", "_")}-${var.quota_id}${local.dimension_suffix}"
  name             = coalesce(var.name, local.default_name)
}

resource "google_cloud_quotas_quota_preference" "preference" {
  parent   = local.parent
  name     = local.name
  service  = var.service
  quota_id = var.quota_id

  dimensions = var.dimensions

  quota_config {
    preferred_value = var.preferred_value
  }

  # Justification is what a human reviewer reads when the ask escalates. An
  # unexplained large increase is the most common rejection cause, so the
  # variable is REQUIRED (see variables.tf) rather than defaulted to "".
  justification = var.justification
  contact_email = var.contact_email

  # QUOTA_DECREASE_BELOW_USAGE / QUOTA_DECREASE_PERCENTAGE_TOO_HIGH are the two
  # guards Google applies to DECREASES. Ignoring them is opt-in and loud.
  # SCHEMA NOTE: a scalar string in the GA provider (7.x), NOT the list the
  # published docs imply — verified against `terraform providers schema`.
  ignore_safety_checks = var.ignore_safety_checks

  lifecycle {
    precondition {
      condition     = var.preferred_value >= -1
      error_message = "preferred_value must be >= -1 (-1 means unlimited)."
    }

    # A quota preference cannot LOWER a limit meaningfully (that is the
    # override resource's job) and a value at/below today's default is a no-op
    # request that still consumes a review cycle. Catch it at plan.
    precondition {
      condition     = var.known_default == null || var.preferred_value > var.known_default
      error_message = "preferred_value (${var.preferred_value}) must EXCEED the known default (${coalesce(var.known_default, 0)}) for ${var.quota_id}. Quota preferences raise limits; to self-throttle use google_service_usage_consumer_quota_override instead."
    }

    # Refuse fixed quotas rather than emitting a request the API will reject.
    precondition {
      condition     = !var.is_fixed
      error_message = "${var.quota_id} is isFixed=true — not self-serve adjustable. It may still be increase-ELIGIBLE via a support case; run tools/quota-report.sh and see knowledge-base/QUOTA-CATALOG.md §0."
    }
  }
}
