<script setup lang="ts">
definePageMeta({ title: 'Transactions' })

// Status filter only applies to the offline-pay (`payment_token`) flow —
// `transfers` (online P2P) carry their own enum and are always included
// when the filter is empty. The backend keeps filtered queries scoped
// to payment_tokens for now.
const states = ['', 'QUEUED', 'SUBMITTED', 'PENDING', 'SETTLED', 'PARTIALLY_SETTLED', 'REJECTED', 'EXPIRED']
const state = ref('')
const page = ref(1)
const perPage = 25

const { data, pending, refresh } = await useFetch<{ items: any[]; total: number }>('/api/transactions', {
  // The backend reads `state` as the status filter for backwards-compat
  // with prior callers; keep the query key as `state` even though the
  // response field is `status`.
  query: computed(() => ({ state: state.value, page: page.value, per_page: perPage })),
})

const totalPages = computed(() => Math.max(1, Math.ceil((data.value?.total ?? 0) / perPage)))
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center gap-3">
      <USelect v-model="state" :items="states.map(s => ({ label: s || 'All states', value: s }))" class="w-56" />
      <div class="text-sm text-gray-500">{{ data?.total ?? 0 }} transactions</div>
    </div>

    <DataTable
      :loading="pending"
      :rows="data?.items || []"
      :row-link="(r: any) => `/transactions/${r.id}`"
      :columns="[
        { key: 'kind', label: 'Kind' },
        { key: 'id', label: 'ID', class: 'font-mono text-xs' },
        { key: 'payer_id', label: 'Payer', class: 'font-mono text-xs' },
        { key: 'payee_id', label: 'Payee', class: 'font-mono text-xs' },
        { key: 'amount_kobo', label: 'Amount' },
        { key: 'sequence_number', label: 'Seq' },
        { key: 'status', label: 'Status' },
        { key: 'created_at', label: 'Created' },
      ]"
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
      <template #cell-sequence_number="{ row }">
        <span :class="row.kind === 'transfer' ? 'text-gray-400' : ''">
          {{ row.kind === 'transfer' ? '—' : row.sequence_number }}
        </span>
      </template>
      <template #cell-status="{ row }"><StateBadge :state="row.status" /></template>
      <template #cell-created_at="{ row }">{{ new Date(row.created_at).toLocaleString() }}</template>
    </DataTable>

    <div class="flex items-center justify-end gap-2">
      <UButton size="sm" variant="ghost" :disabled="page <= 1" @click="page--; refresh()">Prev</UButton>
      <div class="text-sm">{{ page }} / {{ totalPages }}</div>
      <UButton size="sm" variant="ghost" :disabled="page >= totalPages" @click="page++; refresh()">Next</UButton>
    </div>
  </div>
</template>
