# AGENTS.md

Instructions for AI agents working in this repository.

## What this repo is

Customer-side **ARO HCP reference deployment**. Terraform provisions Azure prerequisites (network, Key Vault, 13 HCP managed identities plus one External Secrets Operator workload identity, RBAC), the HCP cluster plus default node pool via AzAPI, and the Entra OIDC app (`externalAuths/entra`). Bash scripts wrap `az aro hcp` for credentials, extra node pools, applying the console secret, and GitOps bootstrap.

This is **not** the Azure/ARO-HCP service codebase. Do not refactor `references/ARO-HCP/` or `references/bennerv-ARO-HCP/` (gitignored clones).

## Sibling: OpenShift virt / RWX

ANF + Trident (later CNV) is a **second IaC run**, not this root:

| | This repo | Sibling [`validated-pattern-openshift-virt`](https://github.com/rh-mobb/validated-pattern-openshift-virt) |
|--|-----------|--------------------------------------------------------------------------------------------------------|
| Role | Cluster + GitOps baseline | `modules/azure` (delegated subnet, ANF pool, Trident identity) + GitOps Trident |
| Canonical | `make cluster.<name>.apply` → kubeconfig → external-auth → bootstrap → **`platform`** | Second checkout; slim `terraform/` reads `platform.json` |
| In-tree | Do **not** call the virt module from this `terraform/` | Deployers may `source = git::…//modules/azure?ref=<tag>` in *their* root |
| Local co-dev | This checkout | Gitignored `references/validated-pattern-openshift-virt` (nested git repo; no submodule) |

- Publish the contract with `make cluster.<name>.platform` (`clusters/<name>/platform.json`, gitignored).
- Reserved ANF CIDR default **`10.0.3.0/24`** (`netapp_subnet_prefix`). Reserved Azure Route Server CIDR default **`10.0.4.0/26`** (`route_server_subnet_prefix`). Jump stays `10.0.2.0/28`. This repo does not create the NetApp or RouteServer subnets.
- Federate **`cluster-api-azure`** to the sibling bgp-cloud-connector ServiceAccount (NIC IP forwarding in the managed RG). Do **not** add a 14th customer MI; least-privilege follow-up is [#20](https://github.com/rh-mobb/validated-pattern-aro-hcp/issues/20).
- **Destroy sibling first** (Trident cleanup + BGP CR drain + ANF + Route Server), then `make cluster.<name>.destroy`.
- Do not implement ANF, Trident CRs, CNV, or Azure Route Server in this tree. Do not add a `make cluster.<name>.storage` that shells into `references/`.

If the user asks only for RWX/virt storage, work in the sibling (or that `references/` clone). If they ask for a cluster, stay here.

## Human docs vs agent docs

Operators follow MkDocs (`docs/`). Agents follow this file plus per-profile [`clusters/<name>/AGENTS.md`](clusters/) when it exists.

| Topic | Human | Agent |
|-------|--------|--------|
| Deploy commands, architecture, cost | [Virt stack](docs/guides/virt-stack.md), [full-stack](docs/prerequisites/full-stack.md), `README.md` | Step tables with **done-when** in `clusters/*/AGENTS.md` |
| Live Azure gates (`TF_VAR_*`, tmux, destroy order) | Short warnings in the guides | This file, [Live Azure](#live-azure-deployments) |
| Extra-hop / CUDN traffic | Virt-stack verify + troubleshooting | [`clusters/aro-virt/AGENTS.md`](clusters/aro-virt/AGENTS.md) |
| Facts (CIDRs, tfvars pins, identity names) | `docs/architecture.md`, example `terraform.tfvars` | Link those; do not invent a second pin list |

Duplicate **procedure** (narrative vs done-when). Duplicate **facts** only when needed for self-contained reading; pins live in Terraform defaults / example tfvars.

If agent and human instructions disagree: **the operator guide wins for command names**; **this file / `clusters/*/AGENTS.md` wins for stop-and-ask**. Fix the loser in the **same PR**. Do not leave a second, drifting `make` sequence (that is how `virt-pool` survived in the sibling).

## Virt example (`clusters/aro-virt`)

When the user asks to deploy, verify extra-hop, or destroy the virt stack:

1. Human path: [Virt stack](docs/guides/virt-stack.md).
2. Agent E2E: [`clusters/aro-virt/AGENTS.md`](clusters/aro-virt/AGENTS.md) (this repo) → sibling `clusters/aro-virt/AGENTS.md` (ANF / Route Server / GitOps) → installer extra-hop section (jump → CUDN on speakers **and** `np-1`).

Jump is **on** (`enable_jumpbox = true`). Set `jump_ssh_source_prefix` and run `make cluster.aro-virt.jump-key` before apply. `np-virt` is in `node_pools` — there is **no** `make cluster.*.virt-pool`.

Do **not** implement Azure Route Server or CUDNs here. Do **not** label extra pools `bgp_router=true` just to get NIC IP forwarding (Azure Route Server **16** BGP peers). CNO stays `ipForwarding: Restricted`, `routingViaHost: false`. OpenShift 4.21.8+ OVN (wrong-node egress) does **not** replace Azure `enableIPForwarding` on the VM/pod node. Customer `az nic update` on managed-RG NICs is RP-denied; sibling DS uses `cluster-api-azure`.


## Source precedence

When sources disagree:

1. **bennerv/ARO-HCP 0.0.2** (`az aro hcp`, API `2026-06-30-preview`) — CLI flags and **RBAC scopes** (CAPI/CCM/ingress/file-csi/image-registry on **VNet**, not subnet).
2. **`references/ARO-HCP/demo/bicep/`** — ARM body shape (etcd KMS, operatorsAuthentication, network defaults).
3. **`references/ARO HCP Hackathon Guide.md`** — regions, quota, troubleshooting, richer Entra/console setup. Stale for RBAC scopes and API version.
4. Service internals in clones — role GUID confirmation only.

## Hard rules

- **Do not** create the cluster via Terraform `local-exec` (AzAPI `azapi_resource` is the cluster path).
- **Do not** copy subnet-scoped CAPI/CCM/ingress RBAC from older Bicep.
- **Network privacy:** RFC1918 or Azure Private Endpoints only. If a path cannot comply, add a row to the exception table in [`docs/architecture.md`](docs/architecture.md#network-privacy) **in the same change**. Do not add public data-plane listeners or public PaaS by default. ANF NFS (sibling) is VNet-delegated RFC1918, not a Private Endpoint — that is compliant.
- **`make` is the interface:** run `make fmt lint test` before claiming work is done.
- **Docs and changelog:** keep [`docs/architecture.md`](docs/architecture.md) in sync with code; update [`CHANGELOG.md`](CHANGELOG.md) only at commit time (see below).
- **Never commit:** operator `clusters/*/terraform.tfvars` (except committed examples), `clusters/*/infrastructure.tfstate*`, `clusters/*/platform.json`, `clusters/*/logs/`, `config/cluster.env`, kubeconfig, Entra secrets, Red Hat pull secrets, downloaded `*.whl`.
- **Live Azure:** do not `apply` / `destroy` unless the user asked. Follow [Live Azure deployments](#live-azure-deployments).
- **Git:** feature branches only; Conventional Commits; no `Co-authored-by: Cursor` or AI trailers.

## Layout

| Path | Purpose |
|------|---------|
| `modules/network/` | RG, VNet, NSG, worker + integration subnets |
| `modules/identities/` | Key Vault, etcd key, optional pull-secret KV secret, 13 HCP MIs + ESO workload identity, RBAC |
| `modules/cluster/` | AzAPI HCP cluster + default node pool |
| `modules/entra/` | Entra OIDC app, redirect URIs from cluster DNS, KV secret, `externalAuths` |
| `modules/jumpbox/` | Optional Fedora jump VM |
| `terraform/` | Thin root: providers, backend, module composition |
| `clusters/<name>/` | Per-cluster `terraform.tfvars` + state; optional `AGENTS.md` (agent E2E, not MkDocs) |
| `scripts/` | Idempotent wrappers: credentials, extra-auth, extra node pools, destroy, GitOps bootstrap |
| `gitops/` | Optional in-cluster GitOps (OLM Subscriptions + Kustomize overlays) |
| `docs/` | Operator guides (MkDocs → GitHub Pages): prerequisites, quick start, extra-auth, GitOps, architecture |
| `mkdocs.yml`, `requirements-docs.txt` | Documentation site config and Python deps |
| `docs/architecture.md` | Resultant resources, RBAC scopes, architecture diagrams |
| `docs/prerequisites/full-stack.md` | Least-privilege permissions per `make cluster.<name>.*` target |
| `CHANGELOG.md` | Commit-scoped operator-visible history (not a work journal) |
| `tests/` | `terraform test` + bats |

## Deploy path

```bash
cp -r clusters/public clusters/my-cluster   # edit terraform.tfvars
make setup
make cluster.my-cluster.apply               # terraform apply (cluster + node pool)
make cluster.my-cluster.kubeconfig          # admin creds (24h TTL)
make cluster.my-cluster.external-auth       # Entra + console (required for a usable console)
make cluster.my-cluster.bootstrap    # optional: GitOps + Web Terminal + Compliance
make cluster.my-cluster.platform            # gitignored platform.json for a sibling virt/storage stack
make cluster.my-cluster.destroy             # reverse teardown (state-rm last pool, then terraform destroy)
```

For **`aro-virt`**, do not invent a parallel sequence. Commands: [Virt stack](docs/guides/virt-stack.md). Agent done-when: [`clusters/aro-virt/AGENTS.md`](clusters/aro-virt/AGENTS.md).

## Live Azure deployments

Use this when the user asks to create, apply, verify, or destroy a real cluster. `make` is the interface. Cluster create is AzAPI in Terraform, not `az aro hcp cluster create` and not Terraform `local-exec`.

A **deploy / create cluster** request means the full path: preflight → `make cluster.<name>.apply` → `make cluster.<name>.kubeconfig` → `make cluster.<name>.external-auth`. Do not stop after apply and wait. Console is not usable until external-auth (otherwise the console URL shows **“Application is not available”** / HTTP 503). Skip kubeconfig or external-auth only if the user explicitly said apply-only.

Apply is **30–60+ minutes**. Destroy is irreversible for the customer RG. Do not start either until the preflight below is clean **or** the user has chosen how to handle conflicts.

### Long-running operations (tmux)

Apply, destroy, and sibling cleanup must outlive the chat turn. A dead foreground shell leaves Azure orphans (HCP cluster, ANF pool, Route Server).

1. **Prefer tmux** whenever `tmux` or the tmux MCP is available. Run `make cluster.<name>.apply` / `.destroy` (and the sibling’s apply/cleanup/destroy) in a session the operator can `tmux attach`. Tee to `clusters/<name>/logs/<utc>-<phase>.log` (gitignored).
2. **Fallback only:** if tmux is not available, use a Cursor **background** shell (`block_until_ms: 0`), same log path. Do not run a 30–60 minute apply/destroy in a foreground tool call that dies with the turn.
3. Do **not** fail preflight solely because tmux is missing.
4. On failure: [Halt vs continue](#halt-vs-continue) — do not invent a second client or revoke to unstick.

### Halt vs continue

One **mutating** Azure operation at a time. Started / Accepted / Provisioning / Deleting (or activity log with no Succeeded / Failed) means the LRO is still in flight.

**Halt and ask** (do not switch APIs or “just try REST”):

- The playbook step’s ARM op never reaches Succeeded or Failed (silent CLI, `Location` HTTP 202 forever, activity log stuck at Started+Accepted).
- You would start a **second** mutating call: another `requestAdminCredential`, REST after CLI, `revokeCredentials`, second apply/destroy, `az group delete`.
- You would write a one-off script or curl loop to work around a hung cloud op.
- The failure is not a local typo, missing file, or a **documented same-command** retry.

**OK without asking:**

- Read-only diagnosis: `az * show`, activity log, GET the **same** LRO’s `Azure-AsyncOperation`, `terraform plan`, `oc get`, public `/readyz`.
- Tiny checkout fixes that **do not** mutate the subscription (parse bug, `depends_on`, docs). Do not then fire a new ARM POST to see if it works.
- Playbook **same-command** retries (e.g. VNet `409 AnotherOperationInProgress` → retry the same `make cluster.<name>.apply` once).

On halt: paste evidence (op name, timestamps, ARM status, activity-log statuses). Wait for wait / revoke / abort / RP bug. Resume **that** step only.

### Preflight (every apply or destroy)

1. **Azure identity.** `az account show` — confirm subscription name/id and user. If missing or unexpected, stop and ask.
2. **`clusters/<name>/terraform.tfvars`.** Must exist (copy from `clusters/public`, `clusters/private`, or `clusters/aro-virt`). Treat it as the intended names, region, and versions. Never commit operator copies. `make cluster.<name>.plan` / `apply` / `destroy` pass `-var-file=clusters/<name>/terraform.tfvars` (beats leftover `TF_VAR_*` for keys in the file).
3. **`TF_VAR_*` leftovers — mandatory.** `-var-file` wins for keys in the cluster tfvars. Leftover `TF_VAR_*` that are **not** in the file (tags, CIDRs, disk size, etc.) still reach Terraform. Scripts after apply (`kubeconfig`, `external-auth`, CLI helpers) read **terraform outputs**, then fall back to the cluster tfvars; env overrides still win. `make test` does **not** pass the var-file and unsets mapped `TF_VAR_*` so CI uses Terraform defaults.

   List them:

   ```bash
   env | grep '^TF_VAR_' || true
   ```

   If **any** `TF_VAR_*` is set (including vars not in the cluster tfvars, such as CIDRs or disk size):

   - Print each `TF_VAR_*` next to the corresponding cluster tfvars value (or “not in cluster tfvars”).
   - **Stop and ask the user** which to do:
     - **A.** Unset the `TF_VAR_*` and deploy from the cluster tfvars.
     - **B.** Keep the `TF_VAR_*` and update the cluster tfvars so operators and Terraform match.
     - **C.** Abort.
   - Do not unset, overwrite, or apply until they pick. Do not assume test leftovers are safe to ignore.
4. **OpenShift versions.** `make cluster.<name>.plan` reads ARM `hcpOpenShiftVersions` for `location` and fails if `cluster_version` / `node_pool_version` are not enabled for their channel. Optional `make cluster.<name>.versions` uses `LOCATION` if set, else `location` from the cluster tfvars.
5. **Existing resources.** `az group show` and `az aro hcp cluster show` (using names from cluster tfvars / terraform outputs). Also `terraform -chdir=terraform state list` with `TF_DATA_DIR=clusters/<name>/.terraform`. If a cluster or non-empty state already exists, stop and ask (apply vs destroy vs leave it).
6. **Plan first.** `make cluster.<name>.plan` and summarize create/change/destroy counts. Proceed to `make cluster.<name>.apply` only if the plan matches what the user asked for.

### After apply

- Confirm `az aro hcp cluster show` and `az aro hcp cluster nodepool show` are `Succeeded`.
- Align cluster tfvars `cluster_name` (and related names) with Terraform outputs if the user chose to keep a `TF_VAR_*` override that is not in the var-file.
- Continue with `make cluster.<name>.kubeconfig` then `make cluster.<name>.external-auth` (the latter depends on kubeconfig). Workers `Ready` is not a finished install; ClusterOperator `console` stays degraded until external-auth.
- After external-auth: console secret present, `oc get co console` Available, console URL HTTP 200, `clusterversion` Available. If Entra app registration fails (insufficient privileges), report the error and the [Entra permissions](docs/guides/external-auth-entra-id.md#directory-roles-least-privilege) needed; do not silently skip.

### Destroy

`make cluster.<name>.destroy` state-rms the default node pool (OCPBUGS-86702) then `terraform destroy`. Always confirm subscription, RG, and cluster name with the user first. If a sibling ANF/Trident stack exists, destroy **that** first (cleanup script + its terraform destroy); this destroy does not call the sibling.

### Do not

- Run `terraform test` and `make cluster.<name>.apply` in the same shell without repeating the `TF_VAR_*` check (`terraform test` variables can leak into the environment).
- Mix jumpbox / private-API work into a **non-virt** deploy unless the user asked for that. `clusters/aro-virt` **includes** the jump box for VNet CUDN tests — follow [`clusters/aro-virt/AGENTS.md`](clusters/aro-virt/AGENTS.md).
- Call `terraform apply` / `destroy` outside Make (that skips `-var-file=clusters/<name>/terraform.tfvars`), or `az group delete` the managed RG.
- Stack a second mutating ARM call (REST after CLI, revoke to unstick) while an LRO is in flight. See [Halt vs continue](#halt-vs-continue).

## Preview API

Targets `2026-06-30-preview` via AzAPI (`hcpOpenShiftClusters` / `nodePools`) and `az aro hcp` for credentials and external-auth.

## Documentation

When a change affects deploy behavior or resultant Azure/Entra/OpenShift resources, update the docs **in the same work**, not later.

**Recipe change workflow:** human guide → `clusters/<name>/AGENTS.md` if that profile has agent E2E → this file if all profiles are affected → sibling `AGENTS.md` / `clusters/*/AGENTS.md` if the other checkout’s sequence changed.

- [`docs/index.md`](docs/index.md) — documentation site home (published at [rh-mobb.github.io/validated-pattern-aro-hcp](https://rh-mobb.github.io/validated-pattern-aro-hcp/)).
- [`docs/prerequisites/account.md`](docs/prerequisites/account.md) — subscription allow-list, RBAC baseline, quotas, tools.
- [`docs/prerequisites/full-stack.md`](docs/prerequisites/full-stack.md) — deployment workflow and [permissions by step](docs/prerequisites/full-stack.md#permissions-by-deployment-step).
- [`docs/guides/external-auth-entra-id.md`](docs/guides/external-auth-entra-id.md) — Entra OIDC, directory roles, consent.
- [`docs/guides/virt-stack.md`](docs/guides/virt-stack.md) — operator virt/ANF/Route Server path (commands).
- [`clusters/aro-virt/AGENTS.md`](clusters/aro-virt/AGENTS.md) — agent virt E2E (done-when, extra-hop). Not published to MkDocs.
- [`docs/architecture.md`](docs/architecture.md) — resource inventory, diagrams, RBAC scopes, CIDRs, identity counts.
- [`README.md`](README.md) — operator path: prerequisites summary, `make` targets, troubleshooting.
- [`clusters/public/terraform.tfvars`](clusters/public/terraform.tfvars) — if a new required variable or default appears. Virt-ready example: [`clusters/aro-virt/terraform.tfvars`](clusters/aro-virt/terraform.tfvars).

Do not leave architecture docs describing the previous identity set, role assignment scopes, network layout, or permission requirements.

After live E2E: add a **Known failure modes** row to the profile `AGENTS.md`. If operators would hit it, add virt-stack (or README) troubleshooting in the same PR.

## Changelog

[`CHANGELOG.md`](CHANGELOG.md) records **committed** deltas only. It is not a debug log.

- **Do not** edit `CHANGELOG.md` while exploring, debugging, or iterating on uncommitted work.
- **Do** add an entry only when creating a git commit, and only for that commit’s diff (`git diff --cached` against `HEAD`).
- Describe operator-visible changes (resources, flags, permissions, deploy/teardown steps). Omit `chore` / `test` / `style` with no operator impact.
- Never record tried-and-reverted steps. The bullets must match what the commit actually introduces.
