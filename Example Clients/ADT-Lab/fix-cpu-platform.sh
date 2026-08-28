#!/usr/bin/env bash
# fix-cpu-platform.sh
# Clears the "Intel Cascade Lake" min_cpu_platform pin from all Cisco and Palo Alto
# instances so they can be migrated to the N4 machine family (Emerald Rapids).
#
# Run this ONCE before the next terraform apply.
# After this script succeeds, run: terraform apply

set -euo pipefail

PROJECT="rteller-demo-svc-e265-aaac"
CISCO_TYPE="n4-standard-4"
PALO_TYPE="n4-standard-4"

declare -A INSTANCES=(
  ["adt-lab-cisco-usc1-a"]="us-central1-a"
  ["adt-lab-cisco-usc1-b"]="us-central1-b"
  ["adt-lab-cisco-use4-a"]="us-east4-a"
  ["adt-lab-cisco-use4-b"]="us-east4-b"
  ["adt-lab-palo-usc1-a"]="us-central1-a"
  ["adt-lab-palo-usc1-b"]="us-central1-b"
  ["adt-lab-palo-use4-a"]="us-east4-a"
  ["adt-lab-palo-use4-b"]="us-east4-b"
)

for INSTANCE in "${!INSTANCES[@]}"; do
  ZONE="${INSTANCES[$INSTANCE]}"

  if [[ "$INSTANCE" == *"cisco"* ]]; then
    MACHINE_TYPE="$CISCO_TYPE"
  else
    MACHINE_TYPE="$PALO_TYPE"
  fi

  echo ""
  echo "──────────────────────────────────────────────"
  echo "  $INSTANCE  ($ZONE)"
  echo "──────────────────────────────────────────────"

  echo "  [1/4] Stopping..."
  gcloud compute instances stop "$INSTANCE" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --quiet

  echo "  [2/4] Clearing min_cpu_platform (cascadelake → Automatic)..."
  gcloud beta compute instances update "$INSTANCE" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --min-cpu-platform="Automatic"

  echo "  [3/4] Setting machine type to $MACHINE_TYPE..."
  gcloud compute instances set-machine-type "$INSTANCE" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --machine-type="$MACHINE_TYPE"

  echo "  [4/4] Starting..."
  gcloud compute instances start "$INSTANCE" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --quiet

  echo "  Done: $INSTANCE"
done

echo ""
echo "All instances updated. Run 'terraform apply' to reconcile Terraform state."
