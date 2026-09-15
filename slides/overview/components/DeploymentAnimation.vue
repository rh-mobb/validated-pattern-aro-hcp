<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from 'vue'
import { useIsSlideActive } from '@slidev/client'
import './diagram-shared.css'

interface VisibleSet {
  hcp: boolean
  vnet: boolean
  customerRg: boolean
  managedRg: boolean
  workers: boolean
  entra: boolean
  argo: boolean
  clusterConfig: boolean
  platform: boolean
  anf: boolean
  routeServer: boolean
  virtStack: boolean
  ocpVirt: boolean
}

interface DeployPhase {
  label: string
  sublabel: string
  repo: 'installer' | 'sibling' | 'none'
  visible: VisibleSet
}

const emptyVisible: VisibleSet = {
  hcp: false,
  vnet: false,
  customerRg: false,
  managedRg: false,
  workers: false,
  entra: false,
  argo: false,
  clusterConfig: false,
  platform: false,
  anf: false,
  routeServer: false,
  virtStack: false,
  ocpVirt: false,
}

const PHASES: DeployPhase[] = [
  {
    label: 'Empty subscription',
    sublabel: 'Nothing deployed yet — next step creates network, identities, and the HCP cluster',
    repo: 'none',
    visible: { ...emptyVisible },
  },
  {
    label: 'Installer apply',
    sublabel: 'make cluster.*.apply — VNet, Key Vault, identities, HCP cluster, node pools',
    repo: 'installer',
    visible: {
      hcp: true,
      vnet: true,
      customerRg: true,
      managedRg: true,
      workers: true,
      entra: false,
      argo: false,
      clusterConfig: false,
      platform: false,
      anf: false,
      routeServer: false,
      virtStack: false,
      ocpVirt: false,
    },
  },
  {
    label: 'Kubeconfig + external-auth',
    sublabel: 'Admin creds · Entra OIDC app · console secret (cluster usable)',
    repo: 'installer',
    visible: {
      hcp: true,
      vnet: true,
      customerRg: true,
      managedRg: true,
      workers: true,
      entra: true,
      argo: false,
      clusterConfig: false,
      platform: false,
      anf: false,
      routeServer: false,
      virtStack: false,
      ocpVirt: false,
    },
  },
  {
    label: 'Installer bootstrap',
    sublabel: 'make cluster.*.bootstrap — Argo CD · cluster-config (ESO, Web Terminal, Compliance)',
    repo: 'installer',
    visible: {
      hcp: true,
      vnet: true,
      customerRg: true,
      managedRg: true,
      workers: true,
      entra: true,
      argo: true,
      clusterConfig: true,
      platform: false,
      anf: false,
      routeServer: false,
      virtStack: false,
      ocpVirt: false,
    },
  },
  {
    label: 'Platform contract',
    sublabel: 'make cluster.*.platform — platform.json for sibling ingest',
    repo: 'installer',
    visible: {
      hcp: true,
      vnet: true,
      customerRg: true,
      managedRg: true,
      workers: true,
      entra: true,
      argo: true,
      clusterConfig: true,
      platform: true,
      anf: false,
      routeServer: false,
      virtStack: false,
      ocpVirt: false,
    },
  },
  {
    label: 'Sibling apply',
    sublabel: 'ANF delegated subnet · Route Server · capacity pool · Trident identity',
    repo: 'sibling',
    visible: {
      hcp: true,
      vnet: true,
      customerRg: true,
      managedRg: true,
      workers: true,
      entra: true,
      argo: true,
      clusterConfig: true,
      platform: true,
      anf: true,
      routeServer: true,
      virtStack: false,
      ocpVirt: false,
    },
  },
  {
    label: 'Sibling bootstrap',
    sublabel: 'virt-stack Application — OpenShift Virtualization · RWX storage · BGP',
    repo: 'sibling',
    visible: {
      hcp: true,
      vnet: true,
      customerRg: true,
      managedRg: true,
      workers: true,
      entra: true,
      argo: true,
      clusterConfig: true,
      platform: true,
      anf: true,
      routeServer: true,
      virtStack: true,
      ocpVirt: true,
    },
  },
]

const PHASE_MS = 4500
const TICK_MS = 60

const phaseIndex = ref(0)
const progress = ref(0)
const paused = ref(false)

const currentPhase = computed(() => PHASES[phaseIndex.value])
const visible = computed(() => currentPhase.value.visible)

let phaseTimer: ReturnType<typeof setInterval> | null = null
let progressTimer: ReturnType<typeof setInterval> | null = null

function stopTimers() {
  if (phaseTimer) { clearInterval(phaseTimer); phaseTimer = null }
  if (progressTimer) { clearInterval(progressTimer); progressTimer = null }
}

function startTimers() {
  if (phaseIndex.value >= PHASES.length - 1) return
  stopTimers()
  phaseTimer = setInterval(() => {
    if (phaseIndex.value >= PHASES.length - 1) {
      pause()
      return
    }
    phaseIndex.value += 1
    progress.value = 0
  }, PHASE_MS)
  progressTimer = setInterval(() => {
    progress.value = Math.min(100, progress.value + (TICK_MS / PHASE_MS) * 100)
  }, TICK_MS)
}

function pause() {
  paused.value = true
  progress.value = 100
  stopTimers()
}

function resume() {
  if (phaseIndex.value >= PHASES.length - 1) return
  paused.value = false
  progress.value = 0
  startTimers()
}

function togglePlayPause() {
  if (paused.value) resume()
  else pause()
}

function handleClick(e: MouseEvent) {
  const dotEl = (e.target as HTMLElement).closest('.dep-dot')
  if (dotEl) {
    const i = Number.parseInt(dotEl.getAttribute('data-index') ?? '0', 10)
    if (i !== phaseIndex.value) {
      phaseIndex.value = i
      pause()
    } else {
      togglePlayPause()
    }
    return
  }
  togglePlayPause()
}

const showEmptyShell = computed(() => phaseIndex.value === 0)

const isActive = useIsSlideActive()

watch(isActive, (active) => {
  if (active) {
    paused.value = false
    phaseIndex.value = 0
    progress.value = 0
    startTimers()
  } else {
    stopTimers()
    phaseIndex.value = 0
    progress.value = 0
    paused.value = false
  }
}, { immediate: true })

onUnmounted(() => stopTimers())
</script>

<template>
  <div class="dep-root d-root" @click="handleClick">
    <div class="dep-header">
      <div class="dep-dots">
        <span
          v-for="(_, i) in PHASES"
          :key="i"
          class="dep-dot"
          :data-index="i"
          :class="{
            active: i === phaseIndex,
            paused: paused && i === phaseIndex,
            installer: PHASES[i].repo === 'installer',
            sibling: PHASES[i].repo === 'sibling',
            neutral: PHASES[i].repo === 'none',
          }"
        />
      </div>
      <div class="dep-label-main">{{ currentPhase.label }}</div>
      <div class="dep-label-sub">
        {{ currentPhase.sublabel }}
        <span v-if="paused" class="dep-resume-hint"> · click anywhere to resume</span>
      </div>
      <span
        v-if="currentPhase.repo !== 'none'"
        class="dep-repo-badge"
        :class="currentPhase.repo === 'installer' ? 'dep-repo-badge--installer' : 'dep-repo-badge--sibling'"
      >
        {{ currentPhase.repo === 'installer' ? 'Installer repo' : 'Sibling virt repo' }}
      </span>
    </div>

    <div class="dep-track">
      <div class="dep-bar" :class="{ paused }" :style="{ width: progress + '%' }" />
    </div>

    <div class="dep-canvas" role="img" aria-label="Deployment build animation">
      <div v-if="showEmptyShell" class="dep-empty-shell">
        Customer Azure subscription
        <span class="dep-empty-hint">empty</span>
      </div>

      <div class="dep-externals">
        <div
          class="dep-item dep-entra d-zone"
          :class="{ 'dep-item--visible': visible.entra }"
        >
          <div class="dep-zone-label dep-label--entra">Entra ID</div>
          <div class="d-node d-node--small dep-node">OIDC login</div>
        </div>
        <div
          class="dep-item dep-service d-zone"
          :class="{ 'dep-item--visible': visible.hcp }"
        >
          <div class="dep-zone-label dep-label--service">ARO HCP</div>
          <div class="d-node d-node--purple d-node--small dep-node">Hosted CP</div>
        </div>
      </div>

      <div
        class="dep-item dep-customer d-zone"
        :class="{ 'dep-item--visible': visible.vnet }"
      >
        <div class="dep-zone-label dep-label--customer">Customer subscription</div>

        <div class="dep-vnet">
          <div class="dep-vnet-label">VNet</div>
          <div class="dep-vnet-row">
            <div
              class="dep-slot dep-slot--installer"
              :class="{ 'dep-item--visible': visible.workers }"
            >
              <div class="d-node d-node--accent d-node--small dep-node">Workers</div>
            </div>
            <div
              class="dep-slot dep-slot--sibling"
              :class="{ 'dep-item--visible': visible.anf }"
            >
              <div class="d-node dep-sibling-node d-node--small dep-node">ANF RWX</div>
            </div>
            <div
              class="dep-slot dep-slot--sibling"
              :class="{ 'dep-item--visible': visible.routeServer }"
            >
              <div class="d-node dep-sibling-node d-node--small dep-node">Route Server</div>
            </div>
          </div>
        </div>

        <div class="dep-workloads">
          <div class="dep-slot dep-slot--installer" :class="{ 'dep-item--visible': visible.workers }">
            <div class="d-node d-node--small dep-node dep-pill">Containers</div>
          </div>
          <div class="dep-slot dep-slot--sibling" :class="{ 'dep-item--visible': visible.ocpVirt }">
            <div class="d-node dep-sibling-node d-node--small dep-node dep-pill">OCP Virt VMs</div>
          </div>
          <div class="dep-slot dep-slot--installer" :class="{ 'dep-item--visible': visible.argo }">
            <div class="d-node d-node--accent d-node--small dep-node dep-pill">Argo CD</div>
          </div>
          <div class="dep-slot dep-slot--installer" :class="{ 'dep-item--visible': visible.clusterConfig }">
            <div class="d-node d-node--accent d-node--small dep-node dep-pill">cluster-config</div>
          </div>
          <div class="dep-slot dep-slot--sibling" :class="{ 'dep-item--visible': visible.virtStack }">
            <div class="d-node dep-sibling-node d-node--small dep-node dep-pill">virt-stack</div>
          </div>
        </div>

        <div class="dep-rg-row">
          <div class="dep-slot" :class="{ 'dep-item--visible': visible.customerRg }">
            <div class="d-node d-node--accent d-node--small dep-node">Customer RG</div>
          </div>
          <div class="dep-slot" :class="{ 'dep-item--visible': visible.managedRg }">
            <div class="d-node dep-managed d-node--small dep-node">Managed RG</div>
          </div>
        </div>
      </div>

      <div
        class="dep-item dep-platform"
        :class="{ 'dep-item--visible': visible.platform }"
      >
        <span class="dep-platform-label">platform.json</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dep-root {
  font-size: 0.52em;
  cursor: pointer;
  user-select: none;
}

.dep-empty-shell {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 9.5rem;
  margin-bottom: 0.35rem;
  border: 2px dashed rgba(120, 120, 120, 0.45);
  border-radius: 10px;
  color: #8a8a8a;
  font-size: 0.95em;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  gap: 0.25rem;
}

.dep-empty-hint {
  font-size: 0.78em;
  font-weight: 500;
  font-style: italic;
  text-transform: lowercase;
  color: #666;
}

.dep-header {
  text-align: center;
  margin-bottom: 0.35rem;
}

.dep-dots {
  display: flex;
  gap: 5px;
  justify-content: center;
  margin-bottom: 5px;
}

.dep-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #3a3a3a;
  cursor: pointer;
  transition: background 0.35s, box-shadow 0.35s;
}

.dep-dot.installer.active { background: #1971c2; }
.dep-dot.sibling.active { background: #f0ab00; }
.dep-dot.neutral.active { background: #888; }
.dep-dot.paused { box-shadow: 0 0 0 2px #e2e2e2; }

.dep-label-main {
  font-size: 0.95em;
  font-weight: 700;
  color: #e8e8e8;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.dep-label-sub {
  font-size: 0.72em;
  color: #9a9a9a;
  margin-top: 3px;
  max-width: 92%;
  margin-left: auto;
  margin-right: auto;
  line-height: 1.35;
}

.dep-resume-hint {
  color: #666;
  font-style: italic;
}

.dep-repo-badge {
  display: inline-block;
  margin-top: 0.35rem;
  padding: 0.12rem 0.45rem;
  border-radius: 4px;
  font-size: 0.72em;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}

.dep-repo-badge--installer {
  color: #1971c2;
  background: rgba(25, 113, 194, 0.15);
  border: 1px solid rgba(25, 113, 194, 0.4);
}

.dep-repo-badge--sibling {
  color: #c58f00;
  background: rgba(240, 171, 0, 0.15);
  border: 1px solid rgba(240, 171, 0, 0.45);
}

.dep-track {
  height: 2px;
  background: #2a2a2a;
  border-radius: 1px;
  margin: 0.35rem 0 0.55rem;
  overflow: hidden;
}

.dep-bar {
  height: 100%;
  background: #ee0000;
  border-radius: 1px;
  transition: width 0.06s linear;
}

.dep-bar.paused { background: #555; }

.dep-canvas {
  position: relative;
  min-height: 11rem;
}

.dep-item,
.dep-slot {
  opacity: 0;
  transform: scale(0.92) translateY(6px);
  transition: opacity 0.45s ease, transform 0.45s ease;
  pointer-events: none;
}

.dep-item--visible {
  opacity: 1;
  transform: scale(1) translateY(0);
  pointer-events: auto;
}

.dep-externals {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.45rem;
  margin-bottom: 0.35rem;
}

.dep-entra {
  background: rgba(230, 119, 0, 0.1);
  border-color: rgba(230, 119, 0, 0.5);
}

.dep-service {
  background: rgba(95, 61, 196, 0.1);
  border-color: rgba(95, 61, 196, 0.55);
}

.dep-customer {
  background: rgba(25, 113, 194, 0.08);
  border-color: rgba(25, 113, 194, 0.55);
}

.dep-label--entra { color: #e67700; }
.dep-label--service { color: #9d7fe8; }
.dep-label--customer { color: #4da3ff; }

.dep-zone-label {
  font-size: 0.82em;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  text-align: center;
  margin-bottom: 0.3rem;
}

.dep-node {
  background: rgba(255, 255, 255, 0.94) !important;
  color: rgba(21, 21, 21, 0.9) !important;
}

.dep-sibling-node {
  border-color: rgba(240, 171, 0, 0.55) !important;
  background: rgba(255, 244, 214, 0.95) !important;
}

.dep-managed {
  border-color: rgba(238, 0, 0, 0.55) !important;
  background: rgba(255, 240, 240, 0.96) !important;
}

.dep-vnet {
  border: 1px dashed rgba(77, 163, 255, 0.35);
  border-radius: 6px;
  padding: 0.3rem;
  margin-bottom: 0.3rem;
}

.dep-vnet-label {
  font-size: 0.75em;
  font-weight: 700;
  color: #8ab4f8;
  text-align: center;
  margin-bottom: 0.25rem;
}

.dep-vnet-row,
.dep-workloads,
.dep-rg-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.28rem;
  justify-content: center;
}

.dep-workloads { margin-bottom: 0.3rem; }

.dep-pill { min-width: 4rem; }

.dep-platform {
  position: absolute;
  right: 0.2rem;
  bottom: 0.1rem;
  padding: 0.2rem 0.45rem;
  border-radius: 5px;
  border: 1px dashed rgba(25, 113, 194, 0.55);
  background: rgba(25, 113, 194, 0.12);
}

.dep-platform-label {
  font-size: 0.82em;
  font-weight: 700;
  color: #8ab4f8;
  font-family: 'JetBrains Mono', monospace;
}
</style>
