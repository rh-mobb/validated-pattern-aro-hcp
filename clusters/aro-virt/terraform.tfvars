# Full-stack example: ARO HCP + reserved ANF CIDR + OpenShift Virtualization workers.
# Operator config for Terraform. Copy to clusters/<name>/terraform.tfvars (gitignored except examples).
# make cluster.<name>.plan/apply/destroy pass this file with -var-file.
#
# Path:
#   make cluster.aro-virt.jump-key          # then set jump_ssh_source_prefix to your /32
#   make cluster.aro-virt.apply
#   make cluster.aro-virt.kubeconfig
#   make cluster.aro-virt.external-auth
#   make cluster.aro-virt.bootstrap
#   make cluster.aro-virt.platform
#   # sibling validated-pattern-openshift-virt:
#   ARO_HCP_ROOT=… ARO_HCP_PROFILE=aro-virt make cluster.aro-virt.apply
#   make cluster.aro-virt.bootstrap          # Trident + CNV + Route Server + BGP sample
#
# Cluster-config repo (org group cluster-admin): GITOPS_REPO=…cluster-config.git
# GITOPS_SOURCE_ROOT=overlays make cluster.aro-virt.bootstrap

location     = "uksouth"
cluster_name = "aro-virt"

cluster_version = "4.22"
cluster_channel = "stable"

# Platform / operator workers (not a supported CNV SKU — 8+ core Dsv5/Dsv6 required).
# availability_zone is Azure zone 1/2/3 (not uksouth-1). Omit to leave unpinned.
node_pool_version = "4.22.9"
node_pool_channel = "stable"

node_pools = {
  np-1 = {
    vm_size           = "Standard_D4s_v6"
    replicas          = 2
    availability_zone = "1"
  }
  # Azure Boost Dsv6, 8+ cores (required for CNV). Quota: +16 vCPU Standard Dsv6.
  # Shared BGP speakers for the virt example (label bgp_router=true). Production
  # should use a dedicated speaker pool — see docs/guides/virt-stack.md.
  np-virt = {
    vm_size           = "Standard_D8s_v6"
    replicas          = 2
    availability_zone = "1"
    labels = {
      workload   = "virtualization"
      bgp_router = "true"
    }
  }
}

api_visibility     = "Public"
ingress_visibility = "Public"

enable_jumpbox = true
# Required when enable_jumpbox is true. SSH 22 from this CIDR only (your public /32).
# Needed to test VNet → CUDN from 10.0.2.4 (see clusters/aro-virt/AGENTS.md extra-hop).
# jump_ssh_source_prefix = "203.0.113.1/32"

# Reserved CIDRs for the sibling virt stack (not created here).
# netapp_subnet_prefix         = "10.0.3.0/24"
# route_server_subnet_prefix   = "10.0.4.0/26"

# Extra virt pool is in node_pools (np-virt). Do not taint unless HyperConverged
# and virt-handler have matching tolerations. Omit subnet_id to use the cluster default.

pull_secret_path = "../tmp/pull-secret.txt"
