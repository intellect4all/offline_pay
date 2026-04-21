<script setup lang="ts">
definePageMeta({ title: 'Overview' })

interface Stats {
  users_total: number
  users_active_24h: number
  users_active_7d: number
  devices_active: number
  // Lien on the main wallet that backs the issued offline ceilings.
  // Wire field is `lien_float_kobo`; dashboard label is "Offline float".
  lien_float_kobo: number
  pending_settlement_kobo: number
  txn_count_24h: number
  txn_volume_24h_kobo: number
  fraud_signals_24h: number
  ceilings_active: number
}

interface VolumePoint { day: string; count: number; volume_kobo: number }

const { data: stats, pending: loadingStats } = await useFetch<Stats>('/api/overview/stats')
const { data: volume } = await useFetch<VolumePoint[]>('/api/overview/volume', { query: { days: 14 } })
const { data: txns } = await useFetch<{ items: any[] }>('/api/transactions', { query: { per_page: 10 } })

const { format } = useKobo()

const maxVolume = computed(() => Math.max(1, ...(volume.value ?? []).map((p) => p.volume_kobo)))
</script>

<template>
  <div class="space-y-6">
    <div v-if="loadingStats" class="text-gray-500">Loading…</div>
    <div v-else-if="stats" class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <StatCard label="Users" :value="stats.users_total" :sublabel="`${stats.users_active_24h} active 24h`" icon="i-lucide-users" />
      <StatCard label="Active devices" :value="stats.devices_active" icon="i-lucide-smartphone" />
      <StatCard label="Offline float" :value="format(stats.lien_float_kobo)" sublabel="Liened on main" icon="i-lucide-piggy-bank" />
      <StatCard label="Pending settlement" :value="format(stats.pending_settlement_kobo)" icon="i-lucide-clock" />
      <StatCard label="Txn volume 24h" :value="format(stats.txn_volume_24h_kobo)" :sublabel="`${stats.txn_count_24h} txns`" icon="i-lucide-arrow-left-right" />
      <StatCard label="Active ceilings" :value="stats.ceilings_active" icon="i-lucide-shield-check" />
      <StatCard label="Fraud signals 24h" :value="stats.fraud_signals_24h" icon="i-lucide-triangle-alert" />
      <StatCard label="Active users 7d" :value="stats.users_active_7d" icon="i-lucide-activity" />
    </div>

    <UCard>
      <template #header>
        <div class="flex items-center justify-between">
          <div class="font-medium">Volume, last 14 days</div>
          <div class="text-xs text-gray-500">kobo</div>
        </div>
      </template>
      <div class="flex items-end gap-1 h-32">
        <div
          v-for="p in volume || []"
          :key="p.day"
          class="flex-1 bg-primary-500/60 hover:bg-primary-500 rounded-t"
          :style="{ height: `${(p.volume_kobo / maxVolume) * 100}%` }"
          :title="`${p.day}: ${format(p.volume_kobo)} (${p.count} txns)`"
        />
      </div>
    </UCard>

    <UCard>
      <template #header>
        <div class="flex items-center justify-between">
          <div class="font-medium">Recent transactions</div>
          <ULink to="/transactions" class="text-xs text-primary-500">View all →</ULink>
        </div>
      </template>
      <DataTable
        :rows="txns?.items || []"
        :columns="[
          { key: 'kind', label: 'Kind' },
          { key: 'id', label: 'ID', class: 'font-mono text-xs' },
          { key: 'payer_id', label: 'Payer', class: 'font-mono text-xs' },
          { key: 'payee_id', label: 'Payee', class: 'font-mono text-xs' },
          { key: 'amount_kobo', label: 'Amount' },
          { key: 'status', label: 'Status' },
          { key: 'created_at', label: 'Created' },
        ]"
        :row-link="(r: any) => `/transactions/${r.id}`"
      >
        <template #cell-kind="{ row }">
          <span
            class="inline-block rounded px-2 py-0.5 text-xs font-medium"
            :class="row.kind === 'transfer'
              ? 'bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200'
              : 'bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-200'"
          >{{ row.kind === 'transfer' ? 'Online P2P' : 'Offline pay' }}</span>
        </template>
        <template #cell-id="{ row }">{{ (row.id as string).slice(0, 10) }}…</template>
        <template #cell-payer_id="{ row }">{{ (row.payer_id as string).slice(0, 10) }}…</template>
        <template #cell-payee_id="{ row }">{{ (row.payee_id as string).slice(0, 10) }}…</template>
        <template #cell-amount_kobo="{ row }"><KoboAmount :kobo="row.amount_kobo" mono /></template>
        <template #cell-status="{ row }"><StateBadge :state="row.status" /></template>
        <template #cell-created_at="{ row }">{{ new Date(row.created_at).toLocaleString() }}</template>
      </DataTable>
    </UCard>
  </div>
</template>
