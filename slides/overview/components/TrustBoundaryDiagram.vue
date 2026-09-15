<script setup lang="ts">
/**
 * Trust boundary: customer subscription vs ARO HCP service.
 * Static diagram for the Trust Boundary slide (replaces Mermaid).
 */
</script>

<template>
  <div class="tb-root" role="img" aria-label="ARO HCP trust boundary diagram">
    <div class="tb-grid">
      <!-- Customer zone -->
      <div class="tb-zone tb-zone--customer">
        <div class="tb-zone-label">Customer Azure subscription</div>

        <div class="tb-flow">
          <div class="tb-node tb-node--operator">Operator / make</div>
          <div class="tb-arrow-down" aria-hidden="true" />

          <div class="tb-mid">
            <div class="tb-subzone tb-subzone--cust">
              <div class="tb-subzone-label">Customer RG</div>
              <div class="tb-node">Terraform prereqs</div>
              <div class="tb-arrow-down tb-arrow-down--short" aria-hidden="true" />
              <div class="tb-node tb-node--accent">hcpOpenShiftClusters</div>
            </div>

            <div class="tb-cross">
              <div class="tb-arrow-right tb-arrow-right--reconcile" aria-hidden="true">
                <span class="tb-cross-label">create / reconcile</span>
              </div>
            </div>

            <div class="tb-subzone tb-subzone--managed">
              <div class="tb-subzone-label">
                Managed RG <span class="tb-tag">deny assignment</span>
              </div>
              <div class="tb-node tb-node--managed">Worker VMs, disks, LB, DNS</div>
              <div class="tb-arrow-down tb-arrow-down--short" aria-hidden="true" />
            </div>
          </div>

          <div class="tb-vnet-row">
            <div class="tb-node tb-node--vnet">Customer VNet</div>
          </div>
        </div>
      </div>

      <!-- Service zone -->
      <div class="tb-zone tb-zone--service">
        <div class="tb-zone-label">ARO HCP service</div>
        <div class="tb-service-stack">
          <div class="tb-node tb-node--service tb-node--rp">Resource provider</div>
          <div class="tb-arrow-down" aria-hidden="true" />
          <div class="tb-node tb-node--service tb-node--hcp">Hosted control plane</div>
        </div>
        <div class="tb-rp-to-mrg" aria-hidden="true" title="RP provisions managed RG" />
        <div class="tb-hcp-to-vnet" aria-hidden="true">
          <span class="tb-dashed-label tb-dashed-label--hcp">VNet integration</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tb-root {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  line-height: 1.25;
  margin: 0.25rem 0 0.5rem;
}

.tb-grid {
  display: grid;
  grid-template-columns: 1fr minmax(9.5rem, 0.42fr);
  gap: 0.65rem;
  align-items: stretch;
}

.tb-zone {
  border: 1.5px solid;
  border-radius: 10px;
  padding: 0.55rem 0.65rem 0.65rem;
}

.tb-zone--customer {
  background: rgba(25, 113, 194, 0.08);
  border-color: rgba(25, 113, 194, 0.55);
}

.tb-zone--service {
  position: relative;
  background: rgba(95, 61, 196, 0.08);
  border-color: rgba(95, 61, 196, 0.55);
  display: flex;
  flex-direction: column;
}

.tb-zone-label {
  font-size: 0.92em;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  margin-bottom: 0.45rem;
}

.tb-zone--customer .tb-zone-label {
  color: rgba(25, 113, 194, 0.95);
}

.tb-zone--service .tb-zone-label {
  color: rgba(95, 61, 196, 0.95);
}

.tb-flow {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
}

.tb-mid {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  gap: 0.35rem;
  width: 100%;
  align-items: center;
}

.tb-subzone {
  border: 1px dashed;
  border-radius: 8px;
  padding: 0.4rem 0.45rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.2rem;
  min-height: 100%;
}

.tb-subzone--cust {
  border-color: rgba(25, 113, 194, 0.35);
  background: rgba(255, 255, 255, 0.45);
}

.tb-subzone--managed {
  border-color: rgba(238, 0, 0, 0.35);
  background: rgba(238, 0, 0, 0.04);
}

.tb-subzone-label {
  font-size: 0.82em;
  font-weight: 700;
  color: rgba(21, 21, 21, 0.65);
  text-align: center;
  width: 100%;
}

.tb-tag {
  display: inline-block;
  margin-left: 0.2rem;
  padding: 0.05rem 0.3rem;
  border-radius: 3px;
  font-size: 0.75em;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: rgba(166, 0, 0, 0.95);
  background: rgba(238, 0, 0, 0.1);
  border: 1px solid rgba(238, 0, 0, 0.25);
}

.tb-node {
  border: 1px solid rgba(21, 21, 21, 0.18);
  border-radius: 6px;
  padding: 0.32rem 0.42rem;
  background: rgba(255, 255, 255, 0.82);
  color: rgba(21, 21, 21, 0.88);
  text-align: center;
  font-weight: 600;
  width: 100%;
  box-sizing: border-box;
}

.tb-node--operator {
  width: auto;
  min-width: 42%;
}

.tb-node--accent {
  border-color: rgba(25, 113, 194, 0.45);
  background: rgba(231, 245, 255, 0.9);
}

.tb-node--managed {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.tb-node--vnet {
  border-color: rgba(25, 113, 194, 0.35);
  background: rgba(231, 245, 255, 0.65);
  font-weight: 700;
  width: 72%;
}

.tb-node--service {
  border-color: rgba(95, 61, 196, 0.35);
  background: rgba(229, 219, 255, 0.75);
}

.tb-service-stack {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
  flex: 1;
  justify-content: center;
  padding-top: 0.5rem;
}

.tb-vnet-row {
  position: relative;
  width: 100%;
  display: flex;
  justify-content: center;
  margin-top: 0.1rem;
}

/* Arrow primitives */
.tb-arrow-down,
.tb-arrow-down--short {
  width: 0;
  height: 0.55rem;
  border-left: 4px solid transparent;
  border-right: 4px solid transparent;
  border-top: 6px solid rgba(21, 21, 21, 0.45);
  position: relative;
}

.tb-arrow-down::before,
.tb-arrow-down--short::before {
  content: '';
  position: absolute;
  left: -1px;
  bottom: 5px;
  width: 2px;
  height: 0.45rem;
  background: rgba(21, 21, 21, 0.45);
}

.tb-arrow-down--short {
  height: 0.4rem;
}

.tb-arrow-down--short::before {
  height: 0.3rem;
}

.tb-cross {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 4.5rem;
}

.tb-arrow-right {
  position: relative;
  width: 100%;
  height: 2px;
  background: rgba(21, 21, 21, 0.45);
}

.tb-arrow-right::after {
  content: '';
  position: absolute;
  right: -1px;
  top: -3px;
  border-top: 4px solid transparent;
  border-bottom: 4px solid transparent;
  border-left: 6px solid rgba(21, 21, 21, 0.45);
}

.tb-cross-label {
  position: absolute;
  top: -1.1rem;
  left: 50%;
  transform: translateX(-50%);
  font-size: 0.78em;
  color: rgba(21, 21, 21, 0.55);
  white-space: nowrap;
}

.tb-rp-to-mrg {
  position: absolute;
  left: -0.65rem;
  top: 4.1rem;
  width: 0.65rem;
  height: 2px;
  background: rgba(21, 21, 21, 0.45);
}

.tb-rp-to-mrg::before {
  content: '';
  position: absolute;
  left: -5px;
  top: -3px;
  border-top: 4px solid transparent;
  border-bottom: 4px solid transparent;
  border-right: 6px solid rgba(21, 21, 21, 0.45);
}

.tb-hcp-to-vnet {
  position: absolute;
  left: -2.8rem;
  bottom: 2.1rem;
  width: 2.8rem;
  height: 2.8rem;
  border-bottom: 2px dashed rgba(95, 61, 196, 0.65);
  border-left: 2px dashed rgba(95, 61, 196, 0.65);
  border-bottom-left-radius: 0.6rem;
  pointer-events: none;
}

.tb-dashed-label {
  font-size: 0.78em;
  color: rgba(95, 61, 196, 0.8);
  white-space: nowrap;
}

.tb-dashed-label--hcp {
  position: absolute;
  left: -0.2rem;
  top: -1.05rem;
}

/* Managed RG → VNet */
.tb-subzone--managed .tb-arrow-down--short {
  margin-top: auto;
}
</style>
