# Federated credential is created after the cluster so the OIDC issuer is known.
# Trust is pinned to the bgp-cloud-connector SA the sibling GitOps creates later.
# Token-exchange as cluster-api-azure is required for NIC IP forwarding: worker
# NICs live in the managed RG behind an RP deny assignment. See issue #20.
resource "azurerm_federated_identity_credential" "bgp_cloud_connector" {
  name      = "capi-bgp-cloud-connector"
  parent_id = module.identities.identity_ids.cluster_api_azure
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.cluster.oidc_issuer_url
  subject   = module.identities.bgp_cloud_connector_federated_subject

  depends_on = [module.cluster]
}
