<script setup lang="ts">
definePageMeta({ title: 'Settlements' })

const page = ref(1)
const perPage = 25

const { data, pending, refresh } = await useFetch<{ items: any[]; total: number }>('/api/settlements', {
  query: computed(() => ({ page: page.value, per_page: perPage })),
})

const totalPages = computed(() => Math.max(1, Math.ceil((data.value?.total ?? 0) / perPage)))
</script>

<template>
  <div class="space-y-4">
    <div class="text-sm text-gray-500">{{ data?.total ?? 0 }} settlement batches</div>

    <DataTable
      :loading="pending"
      :rows="data?.items || []"
      :row-link="(r: any) => `/settlements/${encodeURIComponent(r.id)}`"
      :columns="[
        { key: 'id', label: 'Batch', class: 'font-mono text-xs' },
        { key: 'txn_count', label: 'Txns' },
        { key: 'submitted_volume_kobo', label: 'Submitted' },
        { key: 'settled_volume_kobo', label: 'Settled' },
        { key: 'first_submitted_at', label: 'First submitted' },
        { key: 'last_settled_at', label: 'Last settled' },
      ]"
    >
      <template #cell-submitted_volume_kobo="{ row }"><KoboAmount :kobo="row.submitted_volume_kobo" mono /></template>
      <template #cell-settled_volume_kobo="{ row }"><KoboAmount :kobo="row.settled_volume_kobo" mono /></template>
      <template #cell-first_submitted_at="{ row }">
        {{ row.first_submitted_at ? new Date(row.first_submitted_at).toLocaleString() : '—' }}
      </template>
      <template #cell-last_settled_at="{ row }">
        {{ row.last_settled_at ? new Date(row.last_settled_at).toLocaleString() : '—' }}
      </template>
    </DataTable>

    <div class="flex items-center justify-end gap-2">
      <UButton size="sm" variant="ghost" :disabled="page <= 1" @click="page--; refresh()">Prev</UButton>
      <div class="text-sm">{{ page }} / {{ totalPages }}</div>
      <UButton size="sm" variant="ghost" :disabled="page >= totalPages" @click="page++; refresh()">Next</UButton>
    </div>
  </div>
</template>
