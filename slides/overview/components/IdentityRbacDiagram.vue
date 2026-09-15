<script setup lang="ts">
import './diagram-shared.css'
</script>

<template>
  <div class="d-root id-root" role="img" aria-label="HCP identity and RBAC relationships">
    <div class="id-main">
      <div class="d-node id-svc">service MI</div>

      <div class="id-targets">
        <div class="id-target-row d-row">
          <div class="d-col id-connector">
            <div class="d-edge-label">Reader on each</div>
            <div class="d-arrow-right" aria-hidden="true" />
          </div>
          <div class="d-node d-node--accent id-target">
            9 Control-plane MIs
            <span class="id-detail">CAPI, CP, CCM, ingress, disk/file CSI, image-reg, cloud-net, KMS</span>
          </div>
        </div>

        <div class="id-target-row d-row">
          <div class="d-col id-connector">
            <div class="d-edge-label">Federated Credential</div>
            <div class="d-arrow-right" aria-hidden="true" />
          </div>
          <div class="d-node d-node--accent id-target">
            3 Data-plane MIs
            <span class="id-detail">dp-disk, dp-file, dp-image-registry</span>
          </div>
        </div>
      </div>
    </div>

    <div class="id-eso-row d-row">
      <div class="d-node id-eso">
        ESO workload identity
        <span class="id-detail">not in cluster ARM</span>
      </div>
      <div class="d-col id-connector">
        <div class="d-edge-label d-edge-label--dashed">Key Vault Secrets User</div>
        <div class="d-arrow-right d-arrow-right--dashed" aria-hidden="true" />
      </div>
      <div class="d-node d-node--purple">Key Vault</div>
    </div>
  </div>
</template>

<style scoped>
.id-main {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.65rem;
}

.id-svc {
  min-width: 5rem;
  flex-shrink: 0;
}

.id-targets {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.id-target-row {
  width: 100%;
}

.id-connector {
  min-width: 6.5rem;
  flex-shrink: 0;
}

.id-connector .d-arrow-right {
  width: 100%;
  min-width: 2rem;
}

.id-target {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.id-detail {
  display: block;
  font-size: 0.82em;
  font-weight: 500;
  color: rgba(21, 21, 21, 0.6);
  line-height: 1.35;
}

.id-eso-row {
  padding-top: 0.35rem;
  border-top: 1px dashed rgba(21, 21, 21, 0.15);
  gap: 0.5rem;
}

.id-eso {
  min-width: 8rem;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  flex-shrink: 0;
}
</style>
