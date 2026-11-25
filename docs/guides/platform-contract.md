# Platform and agentic contracts

Sibling stacks (virt, agentic) read a versioned **`platform.json`** from the cluster installer. LLM-specific IaC and GitOps live in [`validated-pattern-aro-agentic`](https://github.com/rh-mobb/validated-pattern-aro-agentic) (or a future cloud-specific installer).

## `platform.json` (installer → siblings)

**Producer (this repo):** `make cluster.<profile>.platform` → gitignored `clusters/<profile>/platform.json` from `terraform output -json platform`.

**Consumers:** sibling Terraform (`platform_json` path), optional in-cluster ConfigMaps.

### Portable core (`contract_version: 1`)

Any OpenShift HCP/classic installer that feeds the agentic stack should publish at least:

| Field | Use |
|-------|-----|
| `contract_version` | Must be `1` today (`scripts/platform.sh` enforces). |
| `installer` | `{ repository, cloud }` — which installer produced the file (e.g. `validated-pattern-aro-hcp`, `azure`). |
| `cluster_name` | Naming, MCP gateway host substitution. |
| `cluster_id` | Correlation, destroy. |
| `cluster_version`, `node_pool_version` | OCP channel pins. |
| `api_url`, `api_visibility` | Verify, docs. |
| `oidc_issuer_url` | Workload identity / federation (where applicable). |
| `node_pools` | Optional pins (labels, zones). |

The **operator bootstrap** path (Lightspeed, COO, RHCL) is largely independent of cloud once the cluster is on **OCP 5.0+**, kubeconfig works, and **External Secrets Operator** can reach a secret store.

### Azure extensions (this installer only)

ARO HCP adds fields required for **Azure sibling IaC** (`modules/azure` in virt and agentic checkouts):

| Field | Use |
|-------|-----|
| `subscription_id`, `tenant_id`, `location` | ARM scope. |
| `resource_group_name` | Customer RG. |
| `network.*` | VNet, worker subnet, NSG, reserved CIDRs. |
| `network.reserved.agentic_pe_subnet_prefix` | Sibling agentic **Azure OpenAI** PE subnet (default `10.0.5.0/28`; not created here). |
| `network.reserved.netapp_subnet_prefix`, `route_server_subnet_prefix` | Virt sibling only. |
| `key_vault_id`, `key_vault_name`, `key_vault_uri` | LLM keys + ESO `ClusterSecretStore` (installer bootstrap). |
| `eso_client_id` | ESO workload identity client ID. |
| `cluster_api_azure_client_id` | Virt BGP / NIC forwarding (not agentic). |

ROSA (or another cloud) would publish the **portable core** plus its own extension block (for example AWS account, Secrets Manager ARNs, VPC identifiers) from **`vp-terraform-rosa`** — not from this repo.

### CIDR reservation (agentic on Azure)

`agentic_pe_subnet_prefix` is validated in this root so the PE subnet does not overlap worker, integration, jump, NetApp, or Route Server reservations. The sibling creates the subnet and Private Endpoint.

## `agentic.json` (sibling → bootstrap)

**Producer:** agentic `make cluster.<profile>.apply` writes gitignored `clusters/<profile>/agentic.json` from `terraform output -json agentic`.

**Consumer:** `scripts/gitops-bootstrap.sh` (OLSConfig templating, ExternalSecret names).

| Field | When |
|-------|------|
| `contract_version` | `1` |
| `llm_backend` | `azure` (default), `none` (operators-only; hand-write LLM fields), future `aws` |
| Azure path | `openai_*`, `key_vault_secret_*`, `lightspeed_llm_provider_name`, `lightspeed_secret_name` |

See the agentic repo [platform contract](https://github.com/rh-mobb/validated-pattern-aro-agentic/blob/main/docs/guides/platform-contract.md) for module layout (`modules/azure`, future `modules/aws`) and bootstrap expectations.

## Workflow summary

```text
Installer (ARO)     platform.json (core + Azure)
       │
       ▼
Agentic sibling     llm_backend=azure → modules/azure → agentic.json
                    llm_backend=aws   → modules/aws   (future)
                    llm_backend=none  → skip cloud LLM IaC; supply agentic.json
       │
       ▼
GitOps bootstrap    COO + Lightspeed + RHCL (cloud-neutral operands)
```