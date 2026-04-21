<script setup lang="ts">
definePageMeta({ title: 'Users' })

interface UserRow {
  id: string
  phone: string
  kyc_tier: string
  main_balance_kobo: number
  offline_balance_kobo: number
  last_seen_at: string | null
  created_at: string
}

const query = ref('')
const page = ref(1)
const perPage = 25

const { data, pending, refresh } = await useFetch<{ items: UserRow[]; total: number }>('/api/users', {
  query: computed(() => ({ q: query.value, page: page.value, per_page: perPage })),
})

const totalPages = computed(() => Math.max(1, Math.ceil((data.value?.total ?? 0) / perPage)))
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center gap-3">
      <UInput v-model="query" placeholder="Search phone or user id…" icon="i-lucide-search" class="max-w-md" />
      <div class="text-sm text-gray-500">{{ data?.total ?? 0 }} users</div>
    </div>

    <DataTable
      :loading="pending"
      :rows="data?.items || []"
      :row-link="(r: UserRow) => `/users/${r.id}`"
      :columns="[
        { key: 'phone', label: 'Phone' },
        { key: 'id', label: 'ID', class: 'font-mono text-xs' },
        { key: 'kyc_tier', label: 'KYC' },
        { key: 'main_balance_kobo', label: 'Main' },
        { key: 'offline_balance_kobo', label: 'Offline' },
        { key: 'last_seen_at', label: 'Last seen' },
      ]"
    >
      <template #cell-id="{ row }">{{ (row.id as string).slice(0, 10) }}…</template>
      <template #cell-main_balance_kobo="{ row }"><KoboAmount :kobo="row.main_balance_kobo" mono /></template>
      <template #cell-offline_balance_kobo="{ row }"><KoboAmount :kobo="row.offline_balance_kobo" mono /></template>
      <template #cell-last_seen_at="{ row }">
        {{ row.last_seen_at ? new Date(row.last_seen_at).toLocaleString() : '—' }}
      </template>
    </DataTable>

    <div class="flex items-center justify-end gap-2">
      <UButton size="sm" variant="ghost" :disabled="page <= 1" @click="page--; refresh()">Prev</UButton>
      <div class="text-sm">{{ page }} / {{ totalPages }}</div>
      <UButton size="sm" variant="ghost" :disabled="page >= totalPages" @click="page++; refresh()">Next</UButton>
    </div>
  </div>
</template>
