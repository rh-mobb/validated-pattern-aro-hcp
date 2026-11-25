# OpenShift 5 agentic stack

Two GitHub checkouts, one cluster. This installer provisions ARO HCP on **OpenShift 5** with baseline GitOps (including External Secrets). Sibling [`layer-ocp-agentic`](https://github.com/rhcs-validated-patterns/layer-ocp-agentic) can provision **cloud LLM IaC** (today `modules/azure` for OpenAI over Private Endpoint) and installs **Cluster Observability (Perses)**, **OpenShift Lightspeed**, and **Red Hat Connectivity Link 1.5 MCP gateway** (Technology Preview).

Portable vs Azure fields in `platform.json` / `agentic.json`: [Platform contract](platform-contract.md).

Do **not** add those operators under this repo’s `gitops/`.

## What you get

| Layer | Repo | Result |
|-------|------|--------|
| Cluster | this repo, e.g. [`clusters/aro-ocp5`](../clusters/aro-ocp5/terraform.tfvars) | OCP **5.0** HCP cluster |
| GitOps baseline | `make cluster.<name>.bootstrap` | GitOps, Web Terminal, Compliance, ESO |
| Platform contract | `make cluster.<name>.platform` | Gitignored `clusters/<name>/platform.json` |
| Azure OpenAI + operators | sibling `make cluster.<name>.apply` + `.bootstrap` | PE subnet `10.0.5.0/28` (default reservation), Lightspeed `OLSConfig`, COO Perses, RHCL MCP |

Azure OpenAI data plane stays on **RFC1918** via Private Endpoint. LLM API keys live in the installer Key Vault and sync via ESO.

## Prerequisites

- [Account prerequisites](../prerequisites/account.md) plus **Azure OpenAI quota** in the cluster region.
- OpenShift **5.0+** (`cluster_version = "5.0"`).
- Two checkouts: this repo and `layer-ocp-agentic` (clone next to this repo or set paths in layer `platform_json`).

## Workflow

```bash
export ARO_HCP_ROOT=/path/to/validated-pattern-aro-hcp

make cluster.aro-ocp5.apply
make cluster.aro-ocp5.kubeconfig
make cluster.aro-ocp5.external-auth
make cluster.aro-ocp5.bootstrap
make cluster.aro-ocp5.platform

cd /path/to/layer-ocp-agentic
export ARO_HCP_ROOT
make cluster.aro-ocp5.apply
make cluster.aro-ocp5.bootstrap
make cluster.aro-ocp5.verify
```

Unset stray `TF_VAR_*` in **both** shells before apply (see [Virt stack](virt-stack.md#0-unset-tf_var_)).

## Destroy order

1. Sibling: `make cluster.<name>.destroy`
2. Installer: `make cluster.<name>.destroy`

## Troubleshooting

| Symptom | Action |
|---------|--------|
| OpenAI create fails | Check Cognitive Services quota and model availability in `location` |
| Lightspeed CSV missing | Confirm `CatalogSource` image for OCP 5 on sibling overlay |
| MCP not Ready | Bootstrap creates `GatewayClass` `openshift-default` + Gateway in `openshift-ingress`; MCP host `mcp.<apps-domain>` |
| Kuadrant MissingDependency | Apply GatewayClass before Kuadrant reconciles; restart `kuadrant-operator` deployment if stale |
| Lightspeed “LLM Backend” (Entra login) | Opaque OAuth UID fails UUID cache check — not Azure OpenAI | Layer [bug write-up](https://github.com/rhcs-validated-patterns/layer-ocp-agentic/blob/main/docs/troubleshooting/lightspeed-entra-invalid-user-id.md) |

Agent done-when: layer [`AGENTS.md`](https://github.com/rhcs-validated-patterns/layer-ocp-agentic/blob/main/AGENTS.md).