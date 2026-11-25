# OpenShift 5 agentic reference profile (layer: layer-ocp-agentic).
# Copy to clusters/<name>/terraform.tfvars for operator use.

location     = "uksouth"
cluster_name = "aro-ocp5"

cluster_version     = "5.0"
cluster_channel     = "stable"
node_pool_version   = "5.0.1"
node_pool_channel   = "stable"

node_pools = {
  np-1 = {
    vm_size  = "Standard_D8s_v6"
    replicas = 6
  }
}

api_visibility     = "Public"
ingress_visibility = "Public"
enable_jumpbox     = false

pull_secret_path = "../tmp/pull-secret.txt"

# Reserved for agentic layer Azure OpenAI Private Endpoint (default 10.0.5.0/28).
# agentic_pe_subnet_prefix = "10.0.5.0/28"