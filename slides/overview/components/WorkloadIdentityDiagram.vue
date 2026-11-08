<script setup lang="ts">
import './diagram-shared.css'

const steps = [
  { from: 'ServiceAccount', to: 'Cluster OIDC Issuer', label: 'Project SA token' },
  { from: 'ServiceAccount', to: 'Azure AD', label: 'Exchange for api://AzureADTokenExchange' },
  { from: 'Azure AD', to: 'Azure AD', label: 'Validate issuer + subject + audience', loop: true },
  { from: 'Azure AD', to: 'ServiceAccount', label: 'Azure access token', return: true },
  { from: 'ServiceAccount', to: 'Azure Resource', label: 'Authenticated request' },
]
</script>

<template>
  <div class="d-root wi-root" role="img" aria-label="Workload identity federation token exchange">
    <div class="wi-participants d-row">
      <div class="d-node wi-part">ServiceAccount</div>
      <div class="d-node wi-part">Cluster OIDC Issuer</div>
      <div class="d-node d-node--purple wi-part">Azure AD</div>
      <div class="d-node d-node--accent wi-part">Azure Resource</div>
    </div>

    <ol class="wi-steps">
      <li v-for="(step, i) in steps" :key="i" class="wi-step">
        <span class="wi-step-num">{{ i + 1 }}</span>
        <span class="wi-step-flow">
          <strong>{{ step.from }}</strong>
          <span class="wi-arrow" :class="{ 'wi-arrow--return': step.return }" aria-hidden="true">→</span>
          <strong>{{ step.to }}</strong>
        </span>
        <span class="wi-step-label">{{ step.label }}</span>
      </li>
    </ol>
  </div>
</template>

<style scoped>
.wi-participants {
  justify-content: space-between;
  gap: 0.4rem;
  margin-bottom: 0.55rem;
  flex-wrap: wrap;
}

.wi-part {
  flex: 1;
  min-width: 4.5rem;
  font-size: 0.88em;
  padding: 0.3rem 0.35rem;
}

.wi-steps {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.28rem;
}

.wi-step {
  display: grid;
  grid-template-columns: 1.2rem 1fr;
  grid-template-rows: auto auto;
  column-gap: 0.45rem;
  row-gap: 0.05rem;
  align-items: baseline;
  padding: 0.22rem 0.35rem;
  border-radius: 5px;
  background: rgba(21, 21, 21, 0.03);
}

.wi-step-num {
  grid-row: 1 / span 2;
  font-weight: 700;
  color: rgba(238, 0, 0, 0.85);
  font-size: 0.9em;
}

.wi-step-flow {
  font-size: 0.88em;
}

.wi-arrow {
  margin: 0 0.2rem;
  color: rgba(21, 21, 21, 0.45);
}

.wi-arrow--return {
  transform: scaleX(-1);
  display: inline-block;
}

.wi-step-label {
  grid-column: 2;
  font-size: 0.82em;
  color: rgba(21, 21, 21, 0.55);
}
</style>
