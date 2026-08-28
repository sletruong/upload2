#!/bin/bash
# Applies only the NCC RA spokes — registers the already-deployed Cisco
# instances into their NCC hubs (wan1/wan2/lan × usc1/use4/usw2).
# Run from deployments/adt-lab/5-appliance/.

set -e

terraform apply \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/wan1-cisco-usc1"]' \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/wan2-cisco-usc1"]' \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/lan-cisco-usc1"]' \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/wan1-cisco-use4"]' \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/wan2-cisco-use4"]' \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/lan-cisco-use4"]' \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/wan1-cisco-usw2"]' \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/wan2-cisco-usw2"]' \
  -target='module.appliance.module.ncc_ra_spoke["rteller-demo-svc-e265-aaac/lan-cisco-usw2"]'
