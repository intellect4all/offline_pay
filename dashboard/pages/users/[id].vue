<script setup lang="ts">
definePageMeta({ title: 'User detail' })

const route = useRoute()
const id = route.params.id as string
const { data, pending, refresh } = await useFetch<any>(`/api/users/${id}`)
</script>

<template>
  <div v-if="pending" class="text-gray-500">Loading…</div>
  <div v-else-if="!data" class="text-gray-500">User not found.</div>
  <div v-else class="space-y-6">
    <div>
      <div class="text-xs uppercase text-gray-500">User</div>
      <div class="text-lg font-semibold font-mono">{{ data.user.id }}</div>
      <div class="text-sm text-gray-600 dark:text-gray-400">
        {{ data.user.phone }} · KYC {{ data.user.kyc_tier }} · created {{ new Date(data.user.created_at).toLocaleString() }}
      </div>
    </div>

    <KYCCard
      :user-id="data.user.id"
      :current-tier="data.user.kyc_tier"
    />

    <UCard>
      <template #header><div class="font-medium">Accounts</div></template>
      <DataTable
        :rows="data.accounts"
        :columns="[
          { key: 'kind', label: 'Kind' },
          { key: 'id', label: 'Account ID', class: 'font-mono text-xs' },
          { key: 'balance_kobo', label: 'Balance' },
        ]"
      >
        <template #cell-balance_kobo="{ row }"><KoboAmount :kobo="row.balance_kobo" mono /></template>
      </DataTable>
    </UCard>

    <UCard>
      <template #header><div class="font-medium">Devices</div></template>
      <DataTable
        :rows="data.devices"
        :columns="[
          { key: 'id', label: 'Device', class: 'font-mono text-xs' },
          { key: 'active', label: 'Active' },
          { key: 'last_seen_at', label: 'Last seen' },
          { key: 'created_at', label: 'Registered' },
        ]"
      >
        <template #cell-active="{ row }">
          <UBadge :color="row.active ? 'success' : 'neutral'" variant="subtle" size="sm">
            {{ row.active ? 'active' : 'inactive' }}
          </UBadge>
        </template>
        <template #cell-last_seen_at="{ row }">
          {{ row.last_seen_at ? new Date(row.last_seen_at).toLocaleString() : '—' }}
        </template>
        <template #cell-created_at="{ row }">{{ new Date(row.created_at).toLocaleString() }}</template>
      </DataTable>
    </UCard>

    <UCard>
      <template #header><div class="font-medium">Ceiling tokens</div></template>
      <DataTable
        :rows="data.ceilings"
        :columns="[
          { key: 'id', label: 'Ceiling', class: 'font-mono text-xs' },
          { key: 'status', label: 'Status' },
          { key: 'amount_kobo', label: 'Amount' },
          { key: 'remaining_kobo', label: 'Remaining' },
          { key: 'expires_at', label: 'Expires' },
        ]"
      >
        <template #cell-status="{ row }"><StateBadge :state="row.status" /></template>
        <template #cell-amount_kobo="{ row }"><KoboAmount :kobo="row.amount_kobo" mono /></template>
        <template #cell-remaining_kobo="{ row }"><KoboAmount :kobo="row.remaining_kobo" mono /></template>
        <template #cell-expires_at="{ row }">{{ new Date(row.expires_at).toLocaleString() }}</template>
      </DataTable>
    </UCard>

    <UCard>
      <template #header><div class="font-medium">Recent transactions (as payer)</div></template>
      <DataTable
        :rows="data.recent_transactions"
        :row-link="(r: any) => `/transactions/${r.id}`"
        :columns="[
          { key: 'id', label: 'ID', class: 'font-mono text-xs' },
          { key: 'amount_kobo', label: 'Amount' },
          { key: 'state', label: 'State' },
          { key: 'created_at', label: 'Created' },
        ]"
      >
        <template #cell-id="{ row }">{{ (row.id as string).slice(0, 10) }}…</template>
        <template #cell-amount_kobo="{ row }"><KoboAmount :kobo="row.amount_kobo" mono /></template>
        <template #cell-state="{ row }"><StateBadge :state="row.state" /></template>
        <template #cell-created_at="{ row }">{{ new Date(row.created_at).toLocaleString() }}</template>
      </DataTable>
    </UCard>

    <UCard>
      <template #header><div class="font-medium">Fraud signals</div></template>
      <DataTable
        :rows="data.fraud"
        empty-label="No fraud signals."
        :columns="[
          { key: 'signal', label: 'Signal' },
          { key: 'severity', label: 'Severity' },
          { key: 'weight', label: 'Weight' },
          { key: 'created_at', label: 'At' },
        ]"
      >
        <template #cell-created_at="{ row }">{{ new Date(row.created_at).toLocaleString() }}</template>
      </DataTable>
    </UCard>
  </div>
</template>
