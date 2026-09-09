mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      client_id       = "00000000-0000-0000-0000-000000000002"
      object_id       = "00000000-0000-0000-0000-000000000003"
      subscription_id = "00000000-0000-0000-0000-000000000004"
    }
  }
}
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      output = {
        properties = {
          platform = {
            issuerUrl = "https://uksouth.oic.aro.azure.com/00000000-0000-0000-0000-000000000001/test"
          }
          api = {
            url = "https://api.test-cluster.3lzd.uksouth.aroapp-hcp.io:443"
          }
          console = {
            url = "https://console-openshift-console.apps.aro.test-cluster.3lzd.uksouth.aroapp-hcp.io"
          }
          dns = {
            baseDomain       = "3lzd.uksouth.aroapp-hcp.io"
            baseDomainPrefix = "test-cluster"
          }
        }
      }
    }
  }

  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        enabled = [
          { name = "4.22.9", channelGroup = "stable" },
          { name = "4.22.10", channelGroup = "stable" },
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
      object_id = "00000000-0000-0000-0000-000000000002"
      client_id = "00000000-0000-0000-0000-000000000003"
    }
  }
}

variables {
  cluster_name        = "test-cluster"
  resource_group_name = "test-rg"
  location            = "uksouth"
}

run "platform_contract_v1_defaults" {
  command = plan

  assert {
    condition     = output.platform.contract_version == 1
    error_message = "platform.contract_version must be 1."
  }

  assert {
    condition     = output.platform.network.reserved.netapp_subnet_prefix == "10.0.3.0/24"
    error_message = "Reserved ANF CIDR must default to 10.0.3.0/24."
  }

  assert {
    condition     = output.platform.network.worker_subnet_prefix == "10.0.0.0/24"
    error_message = "platform.network.worker_subnet_prefix must match the worker subnet."
  }

  assert {
    condition     = output.platform.network.vnet_name == "test-cluster-vnet"
    error_message = "platform.network.vnet_name must be the VNet name."
  }

  assert {
    condition     = output.platform.network.jump_subnet_prefix == "10.0.2.0/28"
    error_message = "platform must publish the jump CIDR so a sibling stack can detect collisions (even when jump is off)."
  }

  assert {
    condition     = output.platform.node_pools["np-1"].availability_zone == "1"
    error_message = "Default np-1 in the platform contract must pin Azure availability zone 1."
  }

  assert {
    condition     = output.netapp_subnet_prefix == "10.0.3.0/24"
    error_message = "netapp_subnet_prefix output must match the reserved CIDR."
  }

  assert {
    condition     = output.platform.network.reserved.route_server_subnet_prefix == "10.0.4.0/26"
    error_message = "Reserved Azure Route Server CIDR must default to 10.0.4.0/26."
  }

  assert {
    condition     = output.route_server_subnet_prefix == "10.0.4.0/26"
    error_message = "route_server_subnet_prefix output must match the reserved CIDR."
  }

  assert {
    condition     = contains(keys(output.platform), "cluster_api_azure_client_id")
    error_message = "platform must publish cluster_api_azure_client_id for sibling BGPCloudConfiguration networkInterfaceClientID."
  }
}

run "capi_federated_credential_trusts_bgp_operator_sa" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.bgp_cloud_connector.subject == "system:serviceaccount:openshift-bgp-cloud-connector:openshift-bgp-cloud-connector-controller-manager"
    error_message = "CAPI federated credential must trust the bgp-cloud-connector manager ServiceAccount."
  }

  assert {
    condition     = azurerm_federated_identity_credential.bgp_cloud_connector.name == "capi-bgp-cloud-connector"
    error_message = "CAPI BGP federated credential name must be capi-bgp-cloud-connector."
  }

  assert {
    condition     = contains(azurerm_federated_identity_credential.bgp_cloud_connector.audience, "api://AzureADTokenExchange")
    error_message = "CAPI BGP federated credential audience must be api://AzureADTokenExchange."
  }
}

run "netapp_cidr_must_not_overlap_jump" {
  command = plan

  variables {
    netapp_subnet_prefix = "10.0.2.0/24"
  }

  expect_failures = [
    terraform_data.platform_cidrs,
  ]
}

run "netapp_cidr_must_be_inside_vnet" {
  command = plan

  variables {
    netapp_subnet_prefix = "192.168.0.0/24"
  }

  expect_failures = [
    terraform_data.platform_cidrs,
  ]
}

run "route_server_cidr_must_not_overlap_netapp" {
  command = plan

  variables {
    route_server_subnet_prefix = "10.0.3.0/26"
  }

  expect_failures = [
    terraform_data.platform_cidrs,
  ]
}

run "route_server_cidr_must_be_inside_vnet" {
  command = plan

  variables {
    route_server_subnet_prefix = "192.168.0.0/26"
  }

  expect_failures = [
    terraform_data.platform_cidrs,
  ]
}

run "route_server_cidr_must_be_at_least_slash_26" {
  command = plan

  variables {
    route_server_subnet_prefix = "10.0.4.0/27"
  }

  expect_failures = [
    terraform_data.platform_cidrs,
  ]
}
