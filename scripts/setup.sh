#!/usr/bin/env bash
# Install and verify tooling for ARO HCP deployment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

check_az_version() {
  require_cmd az
  local version
  version="$(az version --query '"azure-cli"' -o tsv)"
  log "Azure CLI version: ${version}"
}

check_tools() {
  require_cmd jq
  require_cmd terraform
  check_az_version
  if command -v oc >/dev/null 2>&1; then
    log "OpenShift CLI: $(oc version --client 2>/dev/null | head -1 || true)"
  else
    log "WARN: oc not found (required for external-auth and kubeconfig validation)"
  fi
}

install_aro_extension() {
  assert_unified_aro_extension_for_hcp

  log "Installing or upgrading unified az extension aro (includes az aro hcp)"
  az extension add --name aro --upgrade --yes
  assert_unified_aro_extension_for_hcp
  log "az aro hcp extension ready (unified aro)"
}

main() {
  check_tools
  install_aro_extension
  log "Setup complete"
}

main "$@"
