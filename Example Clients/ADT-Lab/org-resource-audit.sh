#!/usr/bin/env bash
# org-resource-audit.sh
# Scans an entire GCP org for compute and serverless resource deployments.
# Uses the Asset Inventory API — one call per resource type, no per-project loops.
#
# Usage:
#   ./org-resource-audit.sh <ORG_ID>
#   ./org-resource-audit.sh 45694343690
#   ./org-resource-audit.sh 91854922466
#
# Requirements: gcloud with roles/cloudasset.viewer at org level

set -euo pipefail

ORG_ID="${1:-}"
if [[ -z "$ORG_ID" ]]; then
  echo "Usage: $0 <ORG_ID>"
  echo "Example: $0 45694343690"
  exit 1
fi

SCOPE="organizations/${ORG_ID}"
DIVIDER="─────────────────────────────────────────────────────────────────────"

query_assets() {
  local label="$1"
  local asset_type="$2"
  local location_field="${3:-location}"   # some types use "location", others differ

  echo ""
  echo "$DIVIDER"
  echo "  ${label}"
  echo "$DIVIDER"

  gcloud asset search-all-resources \
    --scope="$SCOPE" \
    --asset-types="$asset_type" \
    --format="table[box](
        displayName:label=NAME:width=40,
        location:label=LOCATION:width=20,
        project:label=PROJECT:width=35,
        assetType:label=TYPE:width=45
      )" \
    --order-by="project,location" \
    2>/dev/null || echo "  (no results or permission denied for ${asset_type})"
}

echo ""
echo "================================================================="
echo "  GCP Org Resource Audit"
echo "  Org: ${ORG_ID}"
echo "  $(date)"
echo "================================================================="

# ─── Compute Instances ────────────────────────────────────────────────────────
query_assets "COMPUTE ENGINE INSTANCES" \
  "compute.googleapis.com/Instance"

# ─── Cloud Routers (includes Cloud NAT config) ───────────────────────────────
query_assets "CLOUD ROUTERS  (Cloud NAT is embedded in router config)" \
  "compute.googleapis.com/Router"

# ─── Cloud SQL ────────────────────────────────────────────────────────────────
query_assets "CLOUD SQL INSTANCES" \
  "sqladmin.googleapis.com/Instance"

# ─── GKE Clusters ─────────────────────────────────────────────────────────────
query_assets "GKE CLUSTERS" \
  "container.googleapis.com/Cluster"

# ─── Cloud Run Services ───────────────────────────────────────────────────────
query_assets "CLOUD RUN SERVICES" \
  "run.googleapis.com/Service"

# ─── Cloud Functions (1st gen) ────────────────────────────────────────────────
query_assets "CLOUD FUNCTIONS (v1)" \
  "cloudfunctions.googleapis.com/CloudFunction"

# ─── Cloud Functions (2nd gen) ────────────────────────────────────────────────
query_assets "CLOUD FUNCTIONS (v2)" \
  "cloudfunctions.googleapis.com/Function"

# ─── Dataflow Jobs ────────────────────────────────────────────────────────────
query_assets "DATAFLOW JOBS" \
  "dataflow.googleapis.com/Job"

# ─── App Engine ───────────────────────────────────────────────────────────────
query_assets "APP ENGINE SERVICES" \
  "appengine.googleapis.com/Service"

# ─── VPN Gateways ─────────────────────────────────────────────────────────────
query_assets "HA VPN GATEWAYS" \
  "compute.googleapis.com/VpnGateway"

# ─── Interconnects ────────────────────────────────────────────────────────────
query_assets "INTERCONNECT ATTACHMENTS (VLANs)" \
  "compute.googleapis.com/InterconnectAttachment"

# ─── Summary: unique regions in use ──────────────────────────────────────────
echo ""
echo "$DIVIDER"
echo "  UNIQUE LOCATIONS IN USE (Compute Instances)"
echo "$DIVIDER"
gcloud asset search-all-resources \
  --scope="$SCOPE" \
  --asset-types="compute.googleapis.com/Instance" \
  --format="value(location)" \
  2>/dev/null \
  | sort | uniq -c | sort -rn \
  | awk '{printf "  %-6s %s\n", $1, $2}' \
  | sed '1s/^/  COUNT LOCATION\n  ───── ────────────────────\n/'

echo ""
echo "================================================================="
echo "  Audit complete"
echo "================================================================="
