<script setup lang="ts">
import './diagram-shared.css'
</script>

<template>
  <div class="d-root bgp-root" role="img" aria-label="Azure Route Server BGP routing for VM pod IPs">
    <div class="bgp-grid">
      <div class="d-zone bgp-zone--cluster">
        <div class="d-zone-label" style="color: rgba(25, 113, 194, 0.95)">OpenShift cluster</div>
        <div class="bgp-stack">
          <div class="d-node d-node--small">VM (pod overlay IP)</div>
          <div class="d-node d-node--accent d-node--small">FRR speaker pod</div>
        </div>
      </div>

      <div class="bgp-mid d-col">
        <div class="d-edge-label">BGP peer</div>
        <div class="d-arrow-right bgp-peer-arrow" aria-hidden="true" />
      </div>

      <div class="d-zone bgp-zone--azure">
        <div class="d-zone-label" style="color: rgba(95, 61, 196, 0.95)">Azure VNet</div>
        <div class="bgp-stack">
          <div class="d-node d-node--purple d-node--small">Azure Route Server</div>
          <div class="d-col">
            <div class="d-edge-label">inject routes</div>
            <div class="d-arrow-down" aria-hidden="true" />
          </div>
          <div class="d-node d-node--purple d-node--small">VNet effective routes</div>
        </div>
      </div>

      <div class="bgp-ext">
        <div class="d-node bgp-ext-node">External client</div>
        <div class="d-col">
          <div class="d-edge-label">routed via VNet</div>
          <div class="bgp-ext-arrow" aria-hidden="true" />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.bgp-grid {
  display: grid;
  grid-template-columns: 1fr auto 1fr auto;
  gap: 0.45rem;
  align-items: center;
}

.bgp-zone--cluster {
  background: rgba(25, 113, 194, 0.08);
  border-color: rgba(25, 113, 194, 0.55);
}

.bgp-zone--azure {
  background: rgba(95, 61, 196, 0.08);
  border-color: rgba(95, 61, 196, 0.55);
}

.bgp-stack {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}

.bgp-mid {
  min-width: 3.5rem;
  justify-content: center;
}

.bgp-peer-arrow {
  width: 100%;
  min-width: 2rem;
}

.bgp-ext {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
}

.bgp-ext-node {
  border-color: rgba(34, 135, 34, 0.45);
  background: rgba(220, 245, 220, 0.75);
  font-size: 0.92em;
}

.bgp-ext-arrow {
  width: 2.5rem;
  height: 2px;
  background: rgba(21, 21, 21, 0.45);
  transform: rotate(-28deg);
  position: relative;
}

.bgp-ext-arrow::after {
  content: '';
  position: absolute;
  left: -1px;
  top: -3px;
  border-top: 4px solid transparent;
  border-bottom: 4px solid transparent;
  border-right: 6px solid rgba(21, 21, 21, 0.45);
}
</style>
