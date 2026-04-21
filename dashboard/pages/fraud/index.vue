<script setup lang="ts">
definePageMeta({ title: 'Fraud signals' })

interface FraudSignal {
  id: string
  user_id: string
  signal: string
  severity: string
  weight: number
  details: string
  ceiling_token_id: string | null
  transaction_id: string | null
  created_at: string
}

const page = ref(1)
const perPage = 50

const { data, pending, refresh } = await useFetch<{ items: FraudSignal[]; total: number }>(
  '/api/fraud',
  { query: computed(() => ({ page: page.value, per_page: perPage })) },
)

const totalPages = computed(() => Math.max(1, Math.ceil((data.value?.total ?? 0) / perPage)))

function severityTone(s: string): 'error' | 'warning' | 'neutral' | 'info' {
  switch ((s || '').toUpperCase()) {
    case 'HIGH':   return 'error'
    case 'MEDIUM': return 'warning'
    case 'LOW':    return 'info'
    default:       return 'neutral'
  }
}
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center gap-3">
      <div class="text-sm text-gray-500">{{ data?.total ?? 0 }} signals</div>
      <UButton size="sm" variant="ghost" icon="i-lucide-refresh-cw" @click="refresh()">Refresh</UButton>
    </div>

    <DataTable
      :loading="pending"
      :rows="data?.items || []"
      :columns="[
        { key: 'created_at', label: 'When' },
        { key: 'signal', label: 'Signal' },
        { key: 'severity', label: 'Severity' },
        { key: 'user_id', label: 'User', class: 'font-mono text-xs' },
        { key: 'details', label: 'Details' },
        { key: 'weight', label: 'Weight' },
      ]"
    >
      <template #cell-created_at="{ row }">{{ new Date(row.created_at).toLocaleString() }}</template>
      <template #cell-signal="{ row }">
        <span class="font-mono text-xs">{{ row.signal }}</span>
      </template>
      <template #cell-severity="{ row }">
        <UBadge :color="severityTone(row.severity)" variant="subtle" size="sm">{{ row.severity }}</UBadge>
      </template>
      <template #cell-user_id="{ row }">
        <ULink :to="`/users/${row.user_id}`" class="text-primary-500 hover:underline">
          {{ (row.user_id as string).slice(0, 10) }}…
        </ULink>
      </template>
      <template #cell-details="{ row }">
        <span class="text-sm text-gray-600 dark:text-gray-400">{{ row.details || '—' }}</span>
      </template>
      <template #cell-weight="{ row }">
        <span class="font-mono text-xs">{{ row.weight.toFixed(1) }}</span>
      </template>
    </DataTable>

    <div class="flex items-center justify-end gap-2">
      <UButton size="sm" variant="ghost" :disabled="page <= 1" @click="page--; refresh()">Prev</UButton>
      <div class="text-sm">{{ page }} / {{ totalPages }}</div>
      <UButton size="sm" variant="ghost" :disabled="page >= totalPages" @click="page++; refresh()">Next</UButton>
    </div>
  </div>
</template>
