<script setup lang="ts">
import './diagram-shared.css'
</script>

<template>
  <div class="arch-root d-root" role="img" aria-label="ARO HCP plus OpenShift Virtualization architecture overview">
    <div class="arch-externals">
      <div class="arch-external-col">
        <div class="d-zone arch-entra">
          <div class="d-zone-label arch-label--entra">Microsoft Entra ID</div>
          <div class="d-node d-node--small">Console · CLI · Argo CD</div>
        </div>
        <div class="d-col arch-drop" aria-hidden="true">
          <div class="d-edge-label d-edge-label--dashed">OIDC login</div>
          <div class="d-arrow-down" />
        </div>
      </div>

      <div class="arch-external-col">
        <div class="d-zone arch-service">
          <div class="d-zone-label arch-label--service">ARO HCP service</div>
          <div class="arch-service-stack">
            <div class="d-node d-node--purple d-node--small">Hosted control plane</div>
            <div class="d-node d-node--purple d-node--small">Resource provider</div>
          </div>
        </div>
        <div class="d-col arch-drop" aria-hidden="true">
          <div class="d-edge-label">reconcile</div>
          <div class="d-arrow-down" />
        </div>
      </div>
    </div>

    <div class="d-zone arch-customer">
      <div class="d-zone-label arch-label--customer">Customer Azure subscription</div>

      <div class="arch-vnet">
        <div class="arch-vnet-banner">VNet · RFC1918</div>
        <div class="arch-vnet-grid">
          <div class="d-node d-node--accent d-node--small">Worker subnet<br><span class="arch-sub">Managed RG VMs</span></div>
          <div class="d-node arch-sibling-node d-node--small">ANF delegated subnet<br><span class="arch-sub">RWX NFS</span></div>
          <div class="d-node arch-sibling-node d-node--small">Route Server subnet<br><span class="arch-sub">BGP routes</span></div>
          <div class="d-node d-node--accent d-node--small">VNet integration<br><span class="arch-sub">Hosted CP path</span></div>
        </div>
      </div>

      <div class="arch-cluster">
        <div class="arch-cluster-label">OpenShift on worker nodes</div>
        <div class="arch-cluster-items">
          <span class="d-node d-node--small arch-pill">Containers</span>
          <span class="d-node d-node--small arch-pill">OCP Virt VMs</span>
          <span class="d-node d-node--small arch-pill">Argo CD</span>
        </div>
      </div>

      <div class="arch-rg-row">
        <div class="d-node d-node--accent arch-rg">Customer RG<br><span class="arch-sub">Terraform · Key Vault · identities · ARM cluster</span></div>
        <div class="d-node arch-managed arch-rg">
          <span class="arch-managed-title">Managed RG</span>
          <span class="arch-managed-detail">Worker VMs · LB · disks</span>
          <span class="arch-managed-tag">deny assignment</span>
        </div>
      </div>
    </div>

    <div class="arch-repos">
      <div class="arch-repo arch-repo--installer">
        <div class="arch-repo-title">Installer repo</div>
        <div class="arch-repo-body">Cluster · GitOps baseline · platform.json</div>
      </div>
      <div class="arch-repo arch-repo--sibling">
        <div class="arch-repo-title">Sibling virt repo</div>
        <div class="arch-repo-body">RWX storage · OCP Virt · Route Server · BGP</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.arch-root {
  font-size: 0.52em;
}

.arch-externals {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.55rem;
  margin-bottom: 0.15rem;
}

.arch-external-col {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.15rem;
}

.arch-external-col .d-zone {
  width: 100%;
}

.arch-entra {
  background: rgba(230, 119, 0, 0.08);
  border-color: rgba(230, 119, 0, 0.5);
}

.arch-service {
  background: rgba(95, 61, 196, 0.08);
  border-color: rgba(95, 61, 196, 0.55);
}

.arch-label--entra { color: rgba(230, 119, 0, 0.95); }
.arch-label--service { color: rgba(95, 61, 196, 0.95); }
.arch-label--customer { color: rgba(25, 113, 194, 0.95); }

.arch-service-stack {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.arch-drop {
  min-height: 1.4rem;
}

.arch-customer {
  background: rgba(25, 113, 194, 0.06);
  border-color: rgba(25, 113, 194, 0.55);
  margin-bottom: 0.4rem;
}

.arch-vnet {
  border: 1px dashed rgba(25, 113, 194, 0.35);
  border-radius: 8px;
  padding: 0.35rem 0.4rem 0.4rem;
  margin-bottom: 0.35rem;
  background: rgba(255, 255, 255, 0.35);
}

.arch-vnet-banner {
  font-size: 0.82em;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: rgba(25, 113, 194, 0.85);
  text-align: center;
  margin-bottom: 0.3rem;
}

.arch-vnet-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.3rem;
}

.arch-sibling-node {
  border-color: rgba(240, 171, 0, 0.55);
  background: rgba(255, 244, 214, 0.85);
}

.arch-sub {
  display: block;
  font-size: 0.82em;
  font-weight: 500;
  color: rgba(21, 21, 21, 0.58);
  line-height: 1.3;
  margin-top: 0.12rem;
}

.arch-cluster {
  text-align: center;
  margin-bottom: 0.35rem;
}

.arch-cluster-label {
  font-size: 0.82em;
  font-weight: 700;
  color: rgba(21, 21, 21, 0.65);
  margin-bottom: 0.25rem;
}

.arch-cluster-items {
  display: flex;
  justify-content: center;
  gap: 0.3rem;
  flex-wrap: wrap;
}

.arch-pill {
  min-width: 4.5rem;
}

.arch-rg-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.35rem;
}

.arch-rg {
  line-height: 1.35;
}

.arch-managed {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  border: 1.5px solid rgba(238, 0, 0, 0.7);
  background: rgba(255, 240, 240, 0.96);
  color: rgba(21, 21, 21, 0.92);
}

.arch-managed-title {
  font-weight: 700;
  font-size: 1.02em;
}

.arch-managed-detail {
  font-size: 0.88em;
  font-weight: 600;
  color: rgba(21, 21, 21, 0.82);
  line-height: 1.35;
}

.arch-managed-tag {
  align-self: flex-start;
  font-size: 0.78em;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: rgba(166, 0, 0, 0.95);
  background: rgba(238, 0, 0, 0.12);
  border: 1px solid rgba(238, 0, 0, 0.35);
  border-radius: 3px;
  padding: 0.08rem 0.35rem;
}

.arch-repos {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.45rem;
}

.arch-repo {
  border-radius: 8px;
  padding: 0.35rem 0.45rem;
  border: 1.5px solid;
}

.arch-repo--installer {
  border-color: rgba(25, 113, 194, 0.55);
}

.arch-repo--sibling {
  border-color: rgba(240, 171, 0, 0.65);
}

.arch-repo-title {
  font-weight: 700;
  font-size: 0.9em;
  margin-bottom: 0.12rem;
  color: rgba(21, 21, 21, 0.9);
}

.arch-repo-body {
  font-size: 0.84em;
  font-weight: 500;
  color: rgba(21, 21, 21, 0.72);
  line-height: 1.35;
}

.arch-repo--installer,
.arch-repo--sibling {
  background: rgba(255, 255, 255, 0.92);
}
</style>
