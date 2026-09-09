# CDI clone/upload memory (`storageWorkloads`)

Portable guidance for the CDI clone/upload memory fix on OpenShift clusters with OpenShift Virtualization (CNV/KubeVirt), including **ARO**, ROSA, and on-prem.

## Problem

When creating a **DataVolume** via CDI **clone** or **upload** of a large block device (e.g. ~30 Gi Fedora cloud image), CDI workload pods can be **OOMKilled** around **60–70%** progress.

**Symptoms:**

- DataVolume stuck in `CloneInProgress` or upload phase
- CDI pod (`upload-server`, clone importer) in `OOMKilled` state
- Retries may fail with `disk.img: file exists` on a temporary PVC (partial clone left behind)

**Root cause:** CDI clone/upload/import pods default to a **~600M** memory limit unless overridden. Large block-device copies need more RAM. This is not cloud-specific.

## Solution

Set **HyperConverged** `spec.resourceRequirements.storageWorkloads`. The Hyperconverged Cluster Operator (HCO) propagates this to **CDIConfig** `spec.podResourceRequirements` / status defaults used by CDI workload pods.

Validated starting values (increase memory if you still see OOM on larger images):

```yaml
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec:
  resourceRequirements:
    storageWorkloads:
      limits:
        memory: 4Gi
        cpu: "2"
      requests:
        memory: 1Gi
        cpu: "500m"
```

**Merge** into an existing HyperConverged CR — do not replace unrelated `spec` fields (feature gates, live migration, node placement, etc.).

### ARO virt stack (GitOps)

For [`clusters/aro-virt`](../../clusters/aro-virt/), the sibling [`validated-pattern-openshift-virt`](https://github.com/rh-mobb/validated-pattern-openshift-virt) GitOps overlay manages `kubevirt-hyperconverged` at `gitops/operators/cnv/hyperconverged.yaml`. After `make cluster.aro-virt.bootstrap` (sibling), Argo CD applies `storageWorkloads` with the values above.

## Verification

Run before large clone tests:

```bash
# HCO spec
oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv \
  -o jsonpath='{.spec.resourceRequirements.storageWorkloads.limits.memory}{"\n"}'
# Expected: 4Gi

# CDIConfig propagated limits
oc get cdiconfig config -o jsonpath='{.status.defaultPodResourceRequirements.limits.memory}{"\n"}'
# Expected: 4Gi
```

If `cdiconfig` still shows `600M` (or empty):

1. Confirm HyperConverged reconciled (no errors on HCO CSV / HyperConverged status).
2. Wait a few minutes after GitOps sync.
3. Check for another controller or manual CDIConfig override fighting HCO.

## Smoke test

1. Confirm `cdiconfig` memory limit is **4Gi**.
2. Create a DataVolume that **clones** a large source (e.g. Fedora cloud image PVC, ≥ 10 Gi).
3. Watch CDI pods during clone:

   ```bash
   oc get pods -A | grep -E 'upload|importer|clone'
   oc get datavolume -A
   ```

4. **Done when:** DataVolume phase `Succeeded`, no OOMKilled CDI pods.

## Failure modes

| Symptom | Likely cause | Action |
|---------|----------------|--------|
| Clone stuck ~65%, upload OOMKilled | 600M CDI default | Apply `storageWorkloads`; verify `cdiconfig` → 4Gi |
| `disk.img: file exists` after retry | Partial clone on tmp volume | Delete DV, related PVCs, importer/upload pods; clean tmp namespace resources |
| Target PVC Pending during clone | Normal until clone completes | Do not assume storage failure while phase is `CloneInProgress` |
| `cdiconfig` not updating | HCO not reconciled or GitOps drift | Check HyperConverged status; fix Git source of truth |

## What this does not fix

| Topic | Notes |
|-------|-------|
| **RWX storage uid/gid** | KubeVirt often needs `uid`/`gid` **107** on shared filesystem storage classes. Separate from CDI memory. |
| **Storage class / CSI** | Wrong SC, missing CSI driver, or network issues cause different failure modes. |
| **VM node placement** | Schedule VMs on nodes with KVM (`devices.kubevirt.io/kvm`). |
| **Partial clone cleanup** | After OOM, delete stuck DataVolume, tmp PVCs in `openshift-virtualization-os-images`, and test namespace; then retry. |

## Related

- [Virt stack](virt-stack.md) — full ARO virt deploy path
- [HyperConverged resource requirements](https://docs.openshift.com/container-platform/latest/virt/install/installing-virt-web.html) (CNV docs — `storageWorkloads`)
- ROSA reference: [`rosa-virtualization` chart ≥ 1.0.3](https://github.com/rh-mobb/validated-pattern-helm-charts) (`hyperConverged.resourceRequirements.storageWorkloads`)
