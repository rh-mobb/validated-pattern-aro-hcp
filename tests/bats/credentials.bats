#!/usr/bin/env bats

setup() {
  export PATH="${BATS_TEST_DIRNAME}/bin:${PATH}"
  export TFVARS="${BATS_TEST_DIRNAME}/tmp/credentials.tfvars"
  mkdir -p "${BATS_TEST_DIRNAME}/tmp"
  cat >"${TFVARS}" <<'EOF'
location = "uksouth"
cluster_name = "test-cluster"
resource_group_name = "test-rg"
EOF
}

@test "credentials request rejects standalone aro-hcp extension" {
  MOCK_AZ_LEGACY_ARO_HCP=1 run bash "${BATS_TEST_DIRNAME}/../../scripts/credentials.sh" request
  [ "$status" -ne 0 ]
  [[ "$output" == *"aro-hcp"* ]]
  [[ "$output" == *"az extension remove --name aro-hcp"* ]]
  [[ "$output" == *"az extension add --name aro --upgrade"* ]]
}

@test "credentials request fails when unified aro extension missing" {
  MOCK_AZ_NO_ARO=1 run bash "${BATS_TEST_DIRNAME}/../../scripts/credentials.sh" request
  [ "$status" -ne 0 ]
  [[ "$output" == *"az aro hcp is not available"* ]]
}

@test "credentials request proceeds with unified aro extension" {
  MOCK_AZ_LEGACY_ARO_HCP=0 MOCK_AZ_NO_ARO=0 \
    KUBECONFIG_PATH="${BATS_TEST_DIRNAME}/tmp/kubeconfig" \
    run bash "${BATS_TEST_DIRNAME}/../../scripts/credentials.sh" request
  [ "$status" -eq 0 ]
  [[ "$output" == *"Kubeconfig written"* ]]
}
