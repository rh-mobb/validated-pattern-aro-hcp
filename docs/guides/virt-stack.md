# OpenShift Virtualization full stack

Two GitHub checkouts, one cluster. This installer provisions ARO HCP, GitOps, and a virt-ready node pool. Sibling [`validated-pattern-openshift-virt`](https://github.com/rh-mobb/validated-pattern-openshift-virt) provisions Azure NetApp Files, Trident CSI, OpenShift Virtualization, Azure Route Server, and the CUDN BGP operator (in-cluster build of [bgp-cloud-connector](https://github.com/openshift/bgp-cloud-connector), pinned to a commit SHA in the sibling GitOps overlay).

Do **not** create ANF, Trident CRs, CNV, or Azure Route Server in this repository. Do **not** install a second Argo CD.

Agents (done-when, extra-hop, tmux): [`clusters/aro-virt/AGENTS.md`](../../clusters/aro-virt/AGENTS.md). This page is the operator command path.

## What you get

| Layer | Repo | Result |
|-------|------|--------|
| Cluster | this repo, [`clusters/aro-virt`](../../clusters/aro-virt/) | Public API/ingress, Fedora jump (`10.0.2.0/28`, set `jump_ssh_source_prefix`), `np-1` (`Standard_D4s_v6` × 2) + `np-virt` (`Standard_D8s_v6` × 2, labels `workload=virtualization` and `bgp_router=true`, Azure zone `1`) |
| GitOps baseline | this repo `make cluster.aro-virt.bootstrap` | OpenShift GitOps, Web Terminal, Compliance, External Secrets |
| Platform contract | `make cluster.aro-virt.platform` | Gitignored `clusters/aro-virt/platform.json` |
| ANF + Trident + CNV + Route Server | sibling `make cluster.aro-virt.apply` then `.bootstrap` | Delegated subnet `10.0.3.0/24`, `RouteServerSubnet` `10.0.4.0/26`, ANF account/pool, StorageClass `anf-virt`, HyperConverged, bgp-cloud-connector |

ANF NFS is VNet-native RFC1918 (delegated subnet), not a Private Endpoint — see [Network privacy](../architecture.md#network-privacy). Cluster default StorageClass stays **`managed-csi`**. CNV uses `anf-virt` via `storageclass.kubevirt.io/is-default-virt-class`.

Microsoft supports OpenShift Virtualization on ARO only on **Dsv5 / Dsv6 with 8+ cores** (Azure Boost). Keep `np-1` for platform pods. Do not taint `np-virt` unless HyperConverged and virt-handler have matching tolerations.

This example **shares** `np-virt` as BGP speakers (`bgp_router=true`): those nodes run FRR and peer with Azure Route Server. That is enough for a two-node demo (Route Server has two BGP endpoints). **Production** can keep a small speaker pool (Azure Route Server **16 BGP peers** max) and run CUDN/VMs on other workers if those NICs have `enableIPForwarding`. OVN extra-hops VNet ingress from a speaker to the VM’s node; the reply egresses the VM node with the CUDN source, which Azure drops unless forwarding is on. Do **not** label virt nodes `bgp_router=true` just to get that flag.

bgp-cloud-connector only enables forwarding on `routerNodeSelector` today ([RFE #121](https://github.com/openshift/bgp-cloud-connector/issues/121)). Until that ships, the sibling GitOps DaemonSet `azure-nic-ip-forwarding` patches **all worker NICs** using `cluster-api-azure` ([tracking #9](https://github.com/rh-mobb/validated-pattern-openshift-virt/issues/9)).

Speaker (and workaround) NIC IP forwarding uses the installer **`cluster-api-azure`** identity (federated to the bgp-cloud-connector ServiceAccount). The sibling BGP MI only manages Route Server BGP connections in the customer RG. Worker NICs are in the managed RG (RP deny assignment). That token-exchange lets the operator act as full CAPI there — tracked for a tighter identity in installer [#20](https://github.com/rh-mobb/validated-pattern-aro-hcp/issues/20). `platform.json` publishes `cluster_api_azure_client_id` for the sibling Job (`spec.azure.networkInterfaceClientID`).

## Prerequisites

Complete [Account prerequisites](../prerequisites/account.md) and [sibling prerequisites](https://rh-mobb.github.io/validated-pattern-openshift-virt/prerequisites/) in addition to a public cluster:

| Extra | Notes |
|-------|--------|
| Two checkouts | This repo **and** `validated-pattern-openshift-virt` (or gitignored `references/validated-pattern-openshift-virt`) |
| Dsv6 quota | **+16 vCPU** `Standard Dsv6` in `location` (`np-virt` × 2 × 8 cores). Jump adds **+2 vCPU** `Standard_D2s_v6` |
| `Microsoft.NetApp` | Registered; ANF capacity quota. Sibling pool default is **1 TiB** Flexible (billable) |
| Free CIDR | Installer `netapp_subnet_prefix` default `10.0.3.0/24` and `route_server_subnet_prefix` default `10.0.4.0/26` must not overlap worker, integration, jump (`10.0.2.0/28`), or each other |
| Tools | Same as the installer, plus sibling Terraform `>= 1.9` |

Permissions: installer [full-stack by step](../prerequisites/full-stack.md#permissions-by-deployment-step). Sibling apply needs **Contributor + User Access Administrator** on the customer RG (Trident custom role). Sibling bootstrap needs the installer kubeconfig (`cluster-admin`).

## 0. Unset `TF_VAR_*`

Leftover `TF_VAR_*` (ROSA tests, tags, `cluster_name`, `location`) still reach Terraform for keys **not** in the cluster tfvars. Unset them in **the same shell** as every `make cluster.*` in **both** repos:

```bash
env | grep '^TF_VAR_' || true
# If any are set, unset them or align the cluster tfvars. Do not apply until they match.
while IFS= read -r k; do unset "$k"; done < <(env | awk -F= '/^TF_VAR_/ {print $1}')
unset TF_DATA_DIR
```

`-var-file` wins for keys in `clusters/aro-virt/terraform.tfvars`. Env leftovers that are **not** in that file still apply.

## 1. Installer (this repo)

```bash
cp -r clusters/aro-virt clusters/my-virt   # or deploy clusters/aro-virt in place
# Edit location, cluster_name, versions. Example pull_secret_path = "../tmp/pull-secret.txt"
mkdir -p tmp
cp /path/to/pull-secret.txt tmp/pull-secret.txt

make setup
make cluster.aro-virt.jump-key           # clusters/aro-virt/jump + jump.pub
# Set jump_ssh_source_prefix in terraform.tfvars to your public /32
make cluster.aro-virt.plan
make cluster.aro-virt.apply              # ~30–60 min; both node pools + jump
make cluster.aro-virt.kubeconfig         # 24h admin → .kube/config
make cluster.aro-virt.external-auth      # console is 503 until this finishes
```

GitOps + optional org overlay (Entra group `cluster-admin`):

```bash
# Tenant-neutral baseline (this repo):
make cluster.aro-virt.bootstrap

# Or a cluster-config repo (example: MOBB overlay named aro-virt):
GITOPS_REPO=https://github.com/rh-mobb/validated-pattern-aro-hcp-cluster-config.git \
GITOPS_SOURCE_ROOT=overlays \
  make cluster.aro-virt.bootstrap
```

Copying `clusters/aro-virt` to `clusters/my-virt` still bootstraps overlay `aro-virt` when that directory exists under `gitops/overlays/` (or `GITOPS_OVERLAY`). Cluster-config uses `overlays/aro-virt` the same way.

Publish the contract **after** GitOps is up:

```bash
make cluster.aro-virt.platform           # clusters/aro-virt/platform.json (gitignored)
```

Workers `Ready` is not a finished install. Console URL HTTP 200 and `clusterversion` Available need external-auth.

## 2. Sibling (ANF + Trident + CNV + Route Server)

From the **sibling** checkout. Point ingest at the installer profile. Point `oc` at the **installer** kubeconfig (sibling defaults to its own `.kube/config`, which is empty):

```bash
export ARO_HCP_ROOT=/path/to/validated-pattern-aro-hcp
export ARO_HCP_PROFILE=aro-virt
export KUBECONFIG_PATH="${ARO_HCP_ROOT}/.kube/config"
export KUBECONFIG="${KUBECONFIG_PATH}"

# Unset TF_VAR_* again in this shell.
cp -r clusters/aro-virt clusters/my-virt   # or use clusters/aro-virt in place
ARO_HCP_ROOT="${ARO_HCP_ROOT}" ARO_HCP_PROFILE=aro-virt \
  make cluster.aro-virt.plan
ARO_HCP_ROOT="${ARO_HCP_ROOT}" ARO_HCP_PROFILE=aro-virt \
  make cluster.aro-virt.apply              # ANF subnet, RouteServerSubnet, ANF pool, Trident + BGP identities
make cluster.aro-virt.bootstrap            # Argo Application virt-stack + anf-platform-metadata + bgp-platform-metadata
```

One Argo CD instance (`openshift-gitops`). `cluster-config` (installer) and `virt-stack` (sibling) are two Applications on the **same** application controller.

The sibling overlay binds OpenShift `cluster-admin` to `openshift-gitops-argocd-application-controller` so Argo can create Trident ServiceAccounts, `VolumeSnapshotClass`, `TridentOrchestrator`, and `HyperConverged`. The installer baseline does **not** grant that (ESO ignores ServiceAccount drift instead). Tightening that binding: [virt issue #6](https://github.com/rh-mobb/validated-pattern-openshift-virt/issues/6).

## 3. Verify

Installer:

```bash
export KUBECONFIG=/path/to/validated-pattern-aro-hcp/.kube/config
az aro hcp cluster show -g aro-virt-rg -n aro-virt --query provisioningState
oc get nodes -L workload,bgp_router,topology.kubernetes.io/zone
oc get clusterversion
oc get co console
# Console route should return HTTP 200 after external-auth
```

Expect four workers: two unlabeled `np-1`, two `workload=virtualization` / `bgp_router=true` on `np-virt`. Kubernetes zone labels look like `uksouth-1` even when create input was `"1"`.

Sibling / GitOps:

```bash
oc -n openshift-gitops get applications.argoproj.io
# cluster-config and virt-stack: Synced / Healthy

oc get sc
# managed-csi (default)   disk.csi.azure.com
# anf-virt                csi.trident.netapp.io   virt-class annotation

oc -n trident get tbc anf-backend
# PHASE Bound

oc -n openshift-cnv get hyperconverged kubevirt-hyperconverged
# systemHealthStatus healthy

# CDI clone/upload memory (default ~600M OOMs on large images without this)
oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv \
  -o jsonpath='{.spec.resourceRequirements.storageWorkloads.limits.memory}{"\n"}'
# Expected: 4Gi
oc get cdiconfig config -o jsonpath='{.status.defaultPodResourceRequirements.limits.memory}{"\n"}'
# Expected: 4Gi

oc -n openshift-cnv get pods -l kubevirt.io=virt-handler -o wide

oc get bgpcloudconfiguration cluster -o yaml
# spec.platform Azure; status shows Route Server neighbors

oc -n openshift-bgp-cloud-connector get pods
oc -n openshift-bgp-cloud-connector get builds

oc get bgprouting virt
# Ready; operator created ClusterUDN cluster-udn-virt (do not apply a CUDN yourself)
oc get clusteruserdefinednetwork cluster-udn-virt
oc get ns virt --show-labels
# cluster-udn=virt, k8s.ovn.org/primary-user-defined-network=
```

Workloads that should be reachable from the jump / VNet go in namespace **`virt`** (primary CUDN `192.168.100.0/24`). Overlay IPs (`10.128.0.0/14`) are not advertised. Jump ping/HTTP to CUDN on **speakers and `np-1`** (extra-hop): agent playbook [`clusters/aro-virt/AGENTS.md`](../../clusters/aro-virt/AGENTS.md#extra-hop-e2e-after-sibling-bootstrap). OpenShift 4.21.8+ OVN (wrong-node egress) does **not** replace Azure `enableIPForwarding` on the VM/pod node.

Smoke RWX (optional; ANF first volume often takes **5–15 minutes**, CSI may `DeadlineExceeded` then bind on retry):

```bash
oc create ns e2e-anf-test
oc apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwx-smoke
  namespace: e2e-anf-test
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: anf-virt
  resources:
    requests:
      storage: 100Gi
EOF
oc -n e2e-anf-test get pvc rwx-smoke -w
# Bound, then: oc delete ns e2e-anf-test
```

CNV golden images in `openshift-virtualization-os-images` also provision on `anf-virt`.

## 4. Destroy

**Sibling first.** Cleanup deletes BGP CRs (while the operator can still remove Azure peerings) then `anf-virt` PVCs (timeout 180s each). ANF volume delete is slower than that; leftover volumes make `terraform destroy` fail on the capacity pool and NetApp subnet.

```bash
# sibling checkout
export KUBECONFIG_PATH=/path/to/validated-pattern-aro-hcp/.kube/config
# unset TF_VAR_*
make cluster.aro-virt.destroy              # cleanup + terraform destroy
```

If destroy errors `CannotDeleteResource` / `InUseSubnetCannotBeDeleted`, list and delete remaining volumes, wait until the list is empty, then re-run destroy:

```bash
az netappfiles volume list -g aro-virt-rg --account-name aro-virt-anf --pool-name aro-virt-anf-pool -o table
az netappfiles volume delete -g aro-virt-rg --account-name aro-virt-anf --pool-name aro-virt-anf-pool --name <pvc-…> --yes
```

Then the installer:

```bash
# installer checkout; unset TF_VAR_*
make cluster.aro-virt.destroy              # state-rm all Terraform nodePools, then terraform destroy
```

This installer destroy does **not** call the sibling. It also does not delete a leftover Entra app if Graph still shows `aro-virt-cluster-app` after state is empty — an Application Administrator (or app owner) must remove it.

## Troubleshooting

| Symptom | Cause | What to do |
|---------|--------|------------|
| `virt-stack` Forbidden on ServiceAccounts / `VolumeSnapshotClass` / `TridentOrchestrator` / `HyperConverged` | Default GitOps ClusterRole is get/list/watch | Sibling bootstrap pre-applies `virt-stack-gitops-controller` before the Application. If missing: `oc apply -f …/gitops/base/gitops-controller-rbac.yaml`, then sync `virt-stack`. |
| `azure-nic-ip-forwarding` `CreateContainerConfigError` (`configmap "azure-nic-ip-forwarding" not found`) | `bgp-from-metadata` Job did not finish before the DS (old `hook: Sync` ordering) | Upgrade sibling GitOps (Job is sync-wave `4`, DS wave `6`). `oc apply -f …/from-metadata-job.yaml` once, or delete the DS and sync `virt-stack`. |
| `trident-from-metadata` Job hangs on `oc get tridentorchestrator` | Namespaced Role cannot get cluster-scoped CRs | Sibling ClusterRole `trident-from-metadata` (orchestrator + CRD get). |
| PVC Pending, Azure volume `Creating` | ANF create is slow | Wait; do not treat the first CSI timeout as failure. |
| Sibling destroy 409 on the pool | Volumes still exist | Delete ANF volumes, wait, destroy again. |
| Sibling bootstrap `oc whoami` fails | Empty sibling `.kube/config` | `KUBECONFIG_PATH` / `KUBECONFIG` = installer `.kube/config`. |
| Tags / region / name wrong | Leftover `TF_VAR_*` | Unset in the same shell; see step 0. |
| `az aro hcp cluster request-credential` hangs; activity log Started/Accepted only | RP `requestAdminCredential` LRO never terminal (CLI waits on Location HTTP 202) | Wait or open an RP issue. Do not start a second request (REST or CLI) or revoke until you choose that. |
| Jump → **all** CUDN IPs fail; ping **TTL exceeded** from a speaker (`10.0.0.x`); curl times out | OVN-K did not install `br-ex` ingress openflow for `192.168.100.0/24` (race when CUDN patch port is created) | BGP/Azure can still look fine. On a speaker: `ovs-ofctl dump-flows br-ex` must show `priority=300,in_port=1,nw_dst=192.168.100.0/24`. If missing: `oc -n openshift-ovn-kubernetes delete pod -l app=ovnkube-node`, wait for rollout, re-test jump. Agent playbook: [`clusters/aro-virt/AGENTS.md#if-jump-to-any-cudn-fails-ttl-exceeded--all-speakers-too`](../../clusters/aro-virt/AGENTS.md#if-jump-to-any-cudn-fails-ttl-exceeded--all-speakers-too). Do **not** set CNO `ipForwarding: Global`. |
| Jump → CUDN on `np-1` fails; **speakers work** | NIC `enableIPForwarding` false (not the 4.21.8 OVN wrong-node-egress bug) | Sibling DS `azure-nic-ip-forwarding` / CAPI; do not label `np-1` `bgp_router=true`. Agent steps: [`clusters/aro-virt/AGENTS.md`](../../clusters/aro-virt/AGENTS.md#if-jump-to-non-speaker-cudn-fails-speakers-work) |
| DataVolume clone stuck ~65%, CDI pod OOMKilled | CDI default ~600M memory limit | Sibling GitOps sets `storageWorkloads` on HyperConverged; verify `cdiconfig` → 4Gi. See [CDI storage workloads](cnv-cdi-storage-workloads.md). |
| `disk.img: file exists` on clone retry | Partial clone after OOM | Delete DV, tmp PVCs in `openshift-virtualization-os-images`, related pods; retry after `cdiconfig` shows 4Gi. |

## Related

- Sibling [consume modes](https://rh-mobb.github.io/validated-pattern-openshift-virt/guides/consume/)
- [CDI clone/upload memory](cnv-cdi-storage-workloads.md)
- [GitOps bootstrap](gitops.md)
- [Architecture — virt workers](../architecture.md#openshift-virtualization-workers-clustersaro-virt)
- Agent E2E: [`clusters/aro-virt/AGENTS.md`](../../clusters/aro-virt/AGENTS.md)
- [Microsoft: CNV on ARO](https://learn.microsoft.com/en-us/azure/openshift/howto-create-openshift-virtualization)
