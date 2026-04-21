<script setup lang="ts">
interface KYCSubmission {
  id: string
  id_type: 'BVN' | 'NIN'
  id_number: string
  status: 'PENDING' | 'VERIFIED' | 'REJECTED'
  rejection_reason: string | null
  tier_granted: string | null
  submitted_at: string
  verified_at: string | null
}

const props = defineProps<{ userId: string; currentTier: string }>()

const { data: submissions } = await useFetch<KYCSubmission[]>(
  `/api/users/${props.userId}/kyc`,
  { default: () => [] },
)
</script>

<template>
  <UCard>
    <template #header>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="font-medium">KYC</div>
          <StateBadge :state="currentTier" />
        </div>
        <div class="text-xs text-gray-500">Read-only — users self-submit from the app</div>
      </div>
    </template>

    <UAlert
      color="neutral"
      variant="subtle"
      icon="i-lucide-smartphone"
      title="Customers upgrade their own tier"
      description="KYC submission and tier upgrades happen inside the mobile app. Support can see the submission trail here; any policy action (reject, re-request) is handled through the separate compliance workflow."
    />

    <div class="mt-4">
      <div class="text-xs uppercase text-gray-500 mb-2">Submissions</div>
      <DataTable
        :rows="submissions || []"
        empty-label="No submissions yet."
        :columns="[
          { key: 'id_type', label: 'Type' },
          { key: 'id_number', label: 'Number', class: 'font-mono text-xs' },
          { key: 'status', label: 'Status' },
          { key: 'tier_granted', label: 'Tier' },
          { key: 'submitted_at', label: 'Submitted' },
          { key: 'rejection_reason', label: 'Reason' },
        ]"
      >
        <template #cell-status="{ row }"><StateBadge :state="row.status" /></template>
        <template #cell-tier_granted="{ row }">{{ row.tier_granted || '—' }}</template>
        <template #cell-submitted_at="{ row }">{{ new Date(row.submitted_at).toLocaleString() }}</template>
        <template #cell-rejection_reason="{ row }">{{ row.rejection_reason || '—' }}</template>
      </DataTable>
    </div>
  </UCard>
</template>
