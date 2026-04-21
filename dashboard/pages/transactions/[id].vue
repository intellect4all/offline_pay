<script setup lang="ts">
definePageMeta({ title: 'Transaction detail' })

const route = useRoute()
const id = route.params.id as string
const { data, pending } = await useFetch<any>(`/api/transactions/${id}`)
</script>

<template>
  <div v-if="pending" class="text-gray-500">Loading…</div>
  <div v-else-if="!data" class="text-gray-500">Not found.</div>
  <div v-else class="space-y-6">
    <div>
      <div class="text-xs uppercase text-gray-500">
        {{ data.kind === 'transfer' ? 'Online P2P transfer' : 'Offline payment' }}
      </div>
      <div class="text-lg font-semibold font-mono">{{ data.id }}</div>
      <div class="flex items-center gap-3 mt-1">
        <StateBadge :state="data.status" />
        <span v-if="data.kind !== 'transfer'" class="text-sm text-gray-500">seq #{{ data.sequence_number }}</span>
      </div>
    </div>

    <UCard>
      <dl class="grid grid-cols-2 md:grid-cols-3 gap-4 text-sm">
        <div>
          <dt class="text-xs uppercase text-gray-500">Amount</dt>
          <dd class="mt-1 font-mono"><KoboAmount :kobo="data.amount_kobo" mono /></dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">Settled amount</dt>
          <dd class="mt-1 font-mono"><KoboAmount :kobo="data.settled_amount_kobo" mono /></dd>
        </div>
        <div v-if="data.kind !== 'transfer' && data.ceiling_id">
          <dt class="text-xs uppercase text-gray-500">Ceiling</dt>
          <dd class="mt-1 font-mono text-xs">{{ data.ceiling_id }}</dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">Payer</dt>
          <dd class="mt-1 font-mono text-xs">
            <NuxtLink :to="`/users/${data.payer_id}`" class="hover:underline">{{ data.payer_id }}</NuxtLink>
          </dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">Payee</dt>
          <dd class="mt-1 font-mono text-xs">
            <NuxtLink :to="`/users/${data.payee_id}`" class="hover:underline">{{ data.payee_id }}</NuxtLink>
          </dd>
        </div>
        <div v-if="data.kind !== 'transfer'">
          <dt class="text-xs uppercase text-gray-500">Batch</dt>
          <dd class="mt-1 font-mono text-xs">
            <NuxtLink v-if="data.settlement_batch_id" :to="`/settlements/${data.settlement_batch_id}`" class="hover:underline">
              {{ data.settlement_batch_id }}
            </NuxtLink>
            <span v-else>—</span>
          </dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">Created</dt>
          <dd class="mt-1">{{ new Date(data.created_at).toLocaleString() }}</dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">Submitted</dt>
          <dd class="mt-1">{{ data.submitted_at ? new Date(data.submitted_at).toLocaleString() : '—' }}</dd>
        </div>
        <div>
          <dt class="text-xs uppercase text-gray-500">Settled</dt>
          <dd class="mt-1">{{ data.settled_at ? new Date(data.settled_at).toLocaleString() : '—' }}</dd>
        </div>
      </dl>
      <div v-if="data.rejection_reason" class="mt-4">
        <UAlert color="error" variant="subtle" :title="`Rejected: ${data.rejection_reason}`" icon="i-lucide-triangle-alert" />
      </div>
    </UCard>
  </div>
</template>
