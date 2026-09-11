# Agent playbook — `clusters/aro-virt`

Step-by-step **done-when** gates for AI operators. Human runbook (commands, architecture, cost): [Virt stack](../../docs/guides/virt-stack.md). Generic Live Azure (preflight, `TF_VAR_*`, tmux): root [`AGENTS.md`](../../AGENTS.md#live-azure-deployments).

ANF, Trident, CNV, Route Server, and the NIC-forwarding DaemonSet are **not** this repo. After `platform`, continue in sibling `clusters/aro-virt/AGENTS.md` (local clone: `references/validated-pattern-openshift-virt/clusters/aro-virt/AGENTS.md`).

If this file and virt-stack disagree on a `make` target or flag, **virt-stack wins for commands**; **this file wins for stop-and-ask**. Fix the loser in the same PR.

## When to run

- User asks to deploy, verify, or destroy the virt example.
- PR changes `clusters/aro-virt/`, jump, `np-virt` / `bgp_router`, `platform.json` / CAPI federation, or virt-stack destroy order.
- After sibling GitOps changes that affect CUDN extra-hop (sibling playbook, then [extra-hop](#extra-hop-e2e-after-sibling-bootstrap) here).

Skip live E2E for refactors with no operator-facing behavior (note in the PR).

Do **not** claim virt e2e done after installer `apply`. Console needs external-auth; CUDN needs the sibling stack; extra-hop needs jump → non-speaker CUDN.

## Recipe facts

| Item | Value |
|------|--------|
| Profile / `cluster_name` | `aro-virt` |
| Jump | `enable_jumpbox = true`; private `10.0.2.4/28`; set `jump_ssh_source_prefix` to the operator `/32`; `make cluster.aro-virt.jump-key` before apply |
| Pools | `np-1` × 2 (`Standard_D4s_v6`); `np-virt` × 2 (`Standard_D8s_v6`, `workload=virtualization`, `bgp_router=true`) |
| Reserved CIDRs (not created here) | ANF `10.0.3.0/24`, Route Server `10.0.4.0/26` |
| CUDN (sibling) | `BGPRouting` `virt` → `cluster-udn-virt` `192.168.100.0/24`, namespace `virt` |
| Overlay | `10.128.0.0/14` — **not** advertised |

`np-virt` is in `node_pools` (created by apply). There is **no** `make cluster.aro-virt.virt-pool`.

## Steps 0–6 (this repo)

Use tmux when possible ([root AGENTS.md](../../AGENTS.md#long-running-operations-tmux)). Unset leftover `TF_VAR_*` in the **same** session as `make` (Live Azure A/B/C).

### Step 0 — Preflight

Follow root Live Azure preflight. Also:

- `clusters/aro-virt/jump.pub` exists, or you will run `jump-key` in step 1.
- `jump_ssh_source_prefix` is set in the cluster tfvars (not left as the commented example). Destroy still needs the live `/32` (or `TF_VAR_jump_ssh_source_prefix` matching state) when jump is on.

**Done when:** Subscription/user match intent; no unapproved `TF_VAR_*`; operator confirmed RG / cluster / region from tfvars.

### Step 1 — Jump key

```bash
make cluster.aro-virt.jump-key
# Set jump_ssh_source_prefix in clusters/aro-virt/terraform.tfvars to the operator public /32
```

**Done when:** `clusters/aro-virt/jump` + `jump.pub` exist; tfvars has an uncommented `jump_ssh_source_prefix`.

### Step 2 — Plan

```bash
make cluster.aro-virt.plan
```

**Done when:** Plan matches the ask (both pools + jump; no unexpected destroys). Summarize create/change/destroy counts for the operator.

### Step 3 — Apply

```bash
# tmux; 30–60+ minutes
make cluster.aro-virt.apply
```

**Done when:** `az aro hcp cluster show` and both node pools `Succeeded`.

### Step 4 — Kubeconfig + external-auth

```bash
make cluster.aro-virt.kubeconfig
make cluster.aro-virt.external-auth
```

**Done when:** `oc get co console` Available; console URL HTTP 200; `clusterversion` Available. If Entra app create fails, report directory-role needs; do not skip.

If `request-credential` never Succeeded (activity log Started+Accepted only): **halt** ([root Halt vs continue](../../AGENTS.md#halt-vs-continue)). Do not REST-retry or revoke on top of the in-flight LRO.

### Step 5 — Bootstrap

```bash
make cluster.aro-virt.bootstrap
```

**Done when:** OpenShift GitOps is installed; `oc -n openshift-gitops get applications.argoproj.io` shows the installer `cluster-config` (or overlay) healthy or still syncing with a known reason.

### Step 6 — Platform + handoff

```bash
make cluster.aro-virt.platform
```

**Done when:** gitignored `clusters/aro-virt/platform.json` exists and includes `cluster_api_azure_client_id`. **Stop this checkout’s deploy path.** Open the sibling playbook; do not apply ANF/Route Server here.

## Extra-hop e2e (after sibling bootstrap)

Installer-side traffic test. Sibling must have Route Server, `azure-nic-ip-forwarding` on **all** workers, and `BGPRouting` `virt`.

OpenShift **4.21.8+** OVN (wrong-node CUDN egress) is **already assumed** (example pins 4.22). That fix does **not** replace Azure `enableIPForwarding` on the node that emits `src=<CUDN IP>`.

### Datapath

| Piece | Role |
|-------|------|
| Jump `10.0.2.4` | VNet client. SSH, then ping/curl **CUDN** IPs (not overlay). |
| Speakers (`np-virt`, `bgp_router=true`) | FRR eBGP to Route Server. Azure next hop for `192.168.100.0/24`. |
| Non-speakers (`np-1`) | May host CUDN. OVN extra-hops **ingress** from a speaker; **reply** leaves this NIC with `src=<CUDN IP>`. |
| Overlay `10.128.0.0/14` | Not advertised. Jump must **not** reach these. |

### Preconditions (stop if any fail)

```bash
export KUBECONFIG=.kube/config
oc get nodes -L bgp_router,hypershift.openshift.io/nodePool
# np-virt: bgp_router=true; np-1: empty

oc get bgpcloudconfiguration cluster
# platform Azure, phase Ready; peerGroups = Route Server IPs, ebgpMultiHop

oc get bgprouting virt
oc get clusteruserdefinednetwork cluster-udn-virt
oc get routeadvertisements bgp-cc-route-advertisements
# Accepted; advertise=true CUDNs

oc -n openshift-bgp-cloud-connector get ds,pods -l app.kubernetes.io/name=azure-nic-ip-forwarding
# 1/1 on every worker

az network routeserver peering list -g aro-virt-rg --route-server aro-virt-routeserver -o table
# Peer IPs = speaker NICs only. Not np-1.
```

Jump:

```bash
TF_DATA_DIR=clusters/aro-virt/.terraform terraform -chdir=terraform output -raw jump_public_ip
# ssh -i clusters/aro-virt/jump fedora@<pip>
# On jump: ip -4 addr → 10.0.2.4/28
```

CUDN IPs are **not** `oc get pod -o wide` (that is overlay). Use:

```bash
oc -n virt get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\t"}{.metadata.annotations.k8s\.ovn\.org/pod-networks}{"\n"}{end}'
```

Expect `192.168.100.<n>/24` under `virt/cluster-udn-virt`.

### Traffic that must work

Listener in namespace **`virt`** (primary CUDN). A DaemonSet of `thejordanprice/icanhazip-clone` on **port 8080** on every worker is enough (pods on speakers **and** `np-1`).

From the jump (`10.0.2.4`):

1. `ping -c 2 -W 2 192.168.100.<speaker>` → pass
2. `ping -c 2 -W 2 192.168.100.<np-1>` → pass (extra-hop + NIC forwarding)
3. `curl -sS -m 5 http://192.168.100.<any>:8080/` → HTTP 200 body **`10.0.2.4`**
4. `ping` overlay `10.128…` / default VM `10.131…` → **fail**

From a CUDN pod on **np-1**: `ping -c 2 10.0.2.4` and `nc -vz -w 2 10.0.2.4 22` → pass.

**Done when:** (1)–(3) pass and (4) fails. Do not treat speaker-only ping as extra-hop success.

### If jump to any CUDN fails (TTL exceeded / all speakers too)

**Symptom:** Jump ping/curl to **every** `192.168.100.x` fails. Ping shows **TTL exceeded** from a speaker IP (`10.0.0.x`), or TCP times out. BGP and Azure routes can still look healthy.

This is **not** the `np-1`-only NIC-forwarding case. Check this path **first** when speakers fail too.

**Cause:** OVN-K race when the CUDN is created: `ovnkube-controller` programs `br-ex` openflow before `ovn-controller` creates the CUDN patch port. Programming fails once and is **not retried**, so the ingress steal flow for `192.168.100.0/24` is never installed. Internal draft for upstream filing: `references/ovn-bug.md` (gitignored).

**Confirm (read-only):**

```bash
export KUBECONFIG=.kube/config
SPEAKER=$(oc get nodes -l bgp_router=true -o jsonpath='{.items[0].metadata.name}')
OVN=$(oc get pod -n openshift-ovn-kubernetes -l app=ovnkube-node \
  --field-selector spec.nodeName="$SPEAKER" -o jsonpath='{.items[0].metadata.name}')

# Expect: priority=300, in_port=1, nw_dst=192.168.100.0/24 → output:<CUDN patch>
oc exec -n openshift-ovn-kubernetes "$OVN" -c ovnkube-controller -- \
  ovs-ofctl dump-flows br-ex | rg '192\.168\.100|priority=300.*in_port=1'

# Bad: via 10.0.0.1 dev br-ex (host leak). Good: dev ovn-k8s-mp1 / table 1065
oc debug node/"$SPEAKER" --quiet -- chroot /host ip route get 192.168.100.14

# Smoking gun at CUDN create time (~BGPRouting Ready):
oc -n openshift-ovn-kubernetes logs "$OVN" -c ovnkube-controller | \
  rg 'gateway_udn.go:593|Failed to set network cluster_udn.*openflow'
```

**Fix (mutating — OK without halt; rolls node networking locally):**

```bash
# All workers (speakers + np-1). DS recreates pods.
oc -n openshift-ovn-kubernetes delete pod -l app=ovnkube-node

oc -n openshift-ovn-kubernetes rollout status ds/ovnkube-node --timeout=300s
```

Re-check the `br-ex` flow on a speaker, then jump ping → speaker CUDN, then → `np-1` CUDN.

**Do not** patch CNO `ipForwarding: Global` for this symptom — that masks host routing; OSD/ROSA use OVS `br-ex` steal flows with `Restricted`. Do not label `np-1` `bgp_router=true`.

### If jump to non-speaker CUDN fails (speakers work)

1. CUDN IP from the annotation, not overlay.
2. Namespace `virt` with primary UDN.
3. DS logs on **that** node: forwarding true. Crash-loop on `/.azure` → `HOME`/`AZURE_CONFIG_DIR`=`/tmp`.
4. Login identity is **CAPI** client ID (`networkInterfaceClientId`), not the BGP MI.
5. Route Server peers remain speakers only — do not label `np-1` `bgp_router=true`.
6. Customer `az nic update` on managed-RG NICs is expected to deny.

## Destroy

Sibling first (its playbook). Then, same `TF_VAR_*` / tmux rules:

```bash
make cluster.aro-virt.destroy
```

If `jump_ssh_source_prefix` is commented in the example tfvars, set `TF_VAR_jump_ssh_source_prefix` to the prefix still in Terraform state (NSG source) for this destroy only, or restore it in the operator tfvars.

**Done when:** customer RG and managed RG gone; Terraform state empty. Leftover Entra app `aro-virt-cluster-app` may remain if Graph delete lacks directory rights — tell the operator (Application Administrator / app owner).

## Do not

- GitOps a raw `ClusterUserDefinedNetwork` — apply `BGPRouting`; the operator creates the CUDN.
- Set CNO `routingViaHost: true` or `ipForwarding: Global` for this extra-hop.
- Add a 14th customer MI for NIC write ([#20](https://github.com/rh-mobb/validated-pattern-aro-hcp/issues/20)).
- Implement Route Server, ANF, or the forwarding DS in this tree.
- Label non-speakers `bgp_router=true` to get `enableIPForwarding` (Azure Route Server **16** BGP peers).

## Known failure modes

| Symptom | Likely cause | Action |
|---------|----------------|--------|
| `Missing jump_ssh_source_prefix` on apply/destroy | Example tfvars leaves it commented | Operator `/32` in tfvars, or destroy-only `TF_VAR_jump_ssh_source_prefix` matching state |
| Wrong region / name / tags | Leftover `TF_VAR_*` | Live Azure A/B/C; unset in the same shell as `make` |
| Console 503 | Skipped external-auth | Step 4 |
| `request-credential` hangs; activity log Started/Accepted only | RP `requestAdminCredential` LRO never terminal (CLI waits on Location 202) | **Halt.** Do not REST-retry or revoke on top. [Halt vs continue](../../AGENTS.md#halt-vs-continue) |
| Jump ping overlay `10.128…` “fails extra-hop” | Wrong IP | Use CUDN annotation `192.168.100.0/24` |
| Jump → **all** CUDN fails; TTL exceeded from `10.0.0.x`; speakers included | Missing `br-ex` prio-300 flow for `192.168.100.0/24` (OVN patch-port race at CUDN create) | [If jump to any CUDN fails](#if-jump-to-any-cudn-fails-ttl-exceeded--all-speakers-too). Upstream draft: `references/ovn-bug.md` |
| Jump → `np-1` CUDN fails; **speakers work** | NIC `enableIPForwarding` false on that worker | Sibling DS / CAPI; not an OVN 4.21.8 regression |
| DS crash-loop `/.azure` | Azure CLI HOME | `HOME=/tmp` `AZURE_CONFIG_DIR=/tmp` emptyDir |
| Graph cannot delete Entra app | Insufficient directory role | Operator deletes `aro-virt-cluster-app` |

After a new live failure: add a row here. If operators would hit it, add virt-stack troubleshooting in the same PR.
