# `quota_preference` — request a quota increase as code

Wraps `google_cloud_quotas_quota_preference`, the **only** Terraform resource
that can *raise* a GCP quota.

## The three things that surprise people

**1. It is a request, not a setting.** A green `apply` means Google accepted the
*ask*. The limit may not have moved. `reconciling = true` and
`granted_value < preferred_value` are both normal post-apply states, and large
asks route to human review. Always read `granted_value` back before treating
headroom as real — this is the house's *ACTIVE ≠ dataplane* law in quota form.

**2. Its sibling resource cannot help you.**
`google_service_usage_consumer_quota_override` looks like the quota resource but
only *lowers* limits — the provider docs are explicit that consumer overrides
"cannot be used to grant more quota than would be allowed by … the default limit
of the service." It is a self-throttle. Use it to *cap* spend, never to raise a
ceiling. This module deliberately does not wrap it.

**3. `fixed` ≠ unraisable.** The API returns `isFixed` and
`quotaIncreaseEligibility.isEligible` independently, and they co-occur:
`PEERINGS-per-VPC-Network` is *both* fixed *and* increase-eligible. `isFixed`
means "not self-serve adjustable" — a support case can still move it. This
module **refuses fixed quotas at plan time** rather than emitting a request the
API will reject; the `1-shared` stack routes them to a
`quota_support_worksheet` output for a human to file.

## Usage

```hcl
module "peering_headroom" {
  source = "../../modules/quota_preference"

  project_id      = "my-host-project"
  service         = "compute.googleapis.com"
  quota_id        = "NETWORKS-per-project"
  preferred_value = 400
  known_default   = 250              # enables the no-op guard
  justification   = "Estate plan adds 180 spoke VPCs across 3 environments by Q3; default 250 blocks onboarding."
  contact_email   = "neteng@example.com"
}
```

Normally you do not call this directly — you write a document in
`1-shared/quotas/*.yaml` (`schemas/quotas.schema.json`) and the stack fans out.

## Plan-time guards

| Guard | Catches |
|---|---|
| `preferred_value >= -1` | malformed values |
| `preferred_value > known_default` | a request at/below the default — a no-op that still burns a review cycle |
| `!is_fixed` | asking Terraform to self-serve a quota that is not self-serve |
| `ignore_safety_checks` enum | invalid safety-check names (a **string** in GA, not a list) |
| `dimensions` excludes `user`/`resource` | API-rejected scoping keys |
| `justification` ≥ 20 chars | unexplained asks (the top rejection cause) |

## Gotchas

- **`quota_id` spellings are inconsistent by service** and that is Google's
  doing: compute uses `SCREAMING-KEBAB-CASE`, networkconnectivity uses
  `PascalCase`, dns uses `lower-kebab-case`. Copy exact ids from
  `tools/quota-report.sh` — never hand-type them.
- **Dimension *keys* are quota-specific.** A wrong key (`region` on a quota
  scoped by `network_id`) passes Terraform and fails at the API.
- **Destroy hands granted quota back.** The GA provider has no
  `deletion_policy` (it is beta-only), so `terraform destroy` deletes the
  preference and the limit reverts. `prevent_destroy` accepts only literals and
  cannot be driven per-document, so the control is procedural: quota documents
  live in tier 0 (destroyed last), and `terraform state rm` is the escape hatch
  when a stack must come down while keeping the quota.
- **Cloud Quotas is global-only.** Region scoping comes from `dimensions`, never
  from a provider region.
- **ADC callers need `x-goog-user-project`.** Not a Terraform issue, but it is
  why hand-rolled `curl` calls to the API fail confusingly.

## Related

- `knowledge-base/QUOTA-CATALOG.md` — every default our resource surface can hit
- `tools/quota-report.sh` — read live values; `--refresh` re-snapshots them
- `schemas/quotas.schema.json` — the document contract
