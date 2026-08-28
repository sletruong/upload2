# ─── Resource Location Constraint ─────────────────────────────────────────────
# Restricts all GCP resource creation (including VM instances) to the three
# lab regions. Applied at project scope so it does not affect other projects.
#
# Value format: "in:<region>-locations" covers all zones within that region.
# GCP constraint: gcp.resourceLocations
# ──────────────────────────────────────────────────────────────────────────────

resource "google_org_policy_policy" "resource_locations" {
  name   = "projects/${var.project_id}/policies/gcp.resourceLocations"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      values {
        allowed_values = [
          "in:us-central1-locations",
          "in:us-east4-locations",
          "in:us-west2-locations",
        ]
      }
    }
  }
}

resource "google_org_policy_policy" "resource_locations_nonprod" {
  name   = "projects/${var.nonprod_project_id}/policies/gcp.resourceLocations"
  parent = "projects/${var.nonprod_project_id}"

  spec {
    rules {
      values {
        allowed_values = [
          "in:us-central1-locations",
          "in:us-east4-locations",
          "in:us-west2-locations",
        ]
      }
    }
  }
}
