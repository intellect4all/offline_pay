<script setup lang="ts">
definePageMeta({ title: 'Settlement batch' })

const route = useRoute()
const id = route.params.id as string
const { data, pending } = await useFetch<any>(`/api/settlements/${encodeURIComponent(id)}`)
</script>

<template>
  <div v-if="pending" class="text-gray-500">Loading…</div>
  <div v-else-if="!data" class="text-gray-500">Not found.</div>
  <div v-else class="space-y-6">
    <div>
      <div class="text-xs uppercase text-gray-500">Settlement batch</div>
      <div class="text-lg font-semibold font-mono">{{ data.batch.id }}</div>
    </div>

    <UCard>
      <dl class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
        <div>
          <dt class="text-xs uppercase text-gray-500">Txns</dt>
          <dd class="mt-1 text-xl font-semibold">{{ data.batch.txn_count }}</dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">Submitted volume</dt>
          <dd class="mt-1 font-mono"><KoboAmount :kobo="data.batch.submitted_volume_kobo" mono /></dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">Settled volume</dt>
          <dd class="mt-1 font-mono"><KoboAmount :kobo="data.batch.settled_volume_kobo" mono /></dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">States</dt>
          <dd class="mt-1 flex flex-wrap gap-1">
            <StateBadge v-for="(n, s) in data.batch.state_counts" :key="s" :state="`${s} (${n})`" />
          </dd>
        </div>
      </dl>
    </UCard>

    <UCard>
      <template #header><div class="font-medium">Transactions in batch</div></template>
      <DataTable
        :rows="data.transactions"
        :row-link="(r: any) => `/transactions/${r.id}`"
        :columns="[
          { key: 'id', label: 'ID', class: 'font-mono text-xs' },
          { key: 'payer_id', label: 'Payer', class: 'font-mono text-xs' },
          { key: 'payee_id', label: 'Payee', class: 'font-mono text-xs' },
          { key: 'amount_kobo', label: 'Amount' },
          { key: 'settled_amount_kobo', label: 'Settled' },
          { key: 'state', label: 'State' },
        ]"
      >
        <template #cell-id="{ row }">{{ (row.id as string).slice(0, 10) }}…</template>
        <template #cell-payer_id="{ row }">{{ (row.payer_id as string).slice(0, 10) }}…</template>
        <template #cell-payee_id="{ row }">{{ (row.payee_id as string).slice(0, 10) }}…</template>
        <template #cell-amount_kobo="{ row }"><KoboAmount :kobo="row.amount_kobo" mono /></template>
        <template #cell-settled_amount_kobo="{ row }"><KoboAmount :kobo="row.settled_amount_kobo" mono /></template>
        <template #cell-state="{ row }"><StateBadge :state="row.state" /></template>
      </DataTable>
    </UCard>
  </div>
</template>
