<script setup lang="ts">
import './diagram-shared.css'
</script>

<template>
  <div class="d-root go-root" role="img" aria-label="GitOps: one Argo CD controller, two Applications">
    <div class="go-top d-row">
      <div class="d-node d-node--accent go-argo">Argo CD (openshift-gitops)</div>
    </div>

    <div class="go-split">
      <div class="go-branch">
        <div class="d-arrow-down" aria-hidden="true" />
        <div class="d-node go-app">Application: cluster-config</div>
        <div class="go-children">
          <div class="d-node d-node--small">Web Terminal</div>
          <div class="d-node d-node--small">Compliance</div>
          <div class="d-node d-node--small">ESO</div>
        </div>
      </div>

      <div class="go-branch">
        <div class="d-arrow-down" aria-hidden="true" />
        <div class="d-node go-app">Application: virt-stack</div>
        <div class="go-children">
          <div class="d-node d-node--small">Trident</div>
          <div class="d-node d-node--small">HyperConverged</div>
          <div class="d-node d-node--small">bgp-cloud-connector</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.go-top {
  justify-content: center;
}

.go-argo {
  min-width: 14rem;
}

.go-split {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-top: 0.15rem;
}

.go-branch {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.3rem;
}

.go-app {
  border-color: rgba(95, 61, 196, 0.45);
  background: rgba(229, 219, 255, 0.75);
  width: 100%;
  font-size: 0.92em;
}

.go-children {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  width: 100%;
  padding-left: 0.75rem;
  border-left: 2px solid rgba(21, 21, 21, 0.12);
}
</style>
