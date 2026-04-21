<script setup lang="ts">
const props = defineProps<{ state: string | null | undefined }>()

const tone = computed<'primary' | 'success' | 'warning' | 'error' | 'neutral' | 'info'>(() => {
  switch (props.state) {
    case 'QUEUED':            return 'neutral'
    case 'SUBMITTED':         return 'info'
    case 'PENDING':           return 'warning'
    case 'SETTLED':           return 'success'
    case 'PARTIALLY_SETTLED': return 'warning'
    case 'REJECTED':          return 'error'
    case 'EXPIRED':           return 'neutral'
    case 'ACTIVE':            return 'success'
    case 'REVOKED':           return 'error'
    case 'EXHAUSTED':         return 'neutral'
    default:                  return 'neutral'
  }
})
</script>

<template>
  <UBadge :color="tone" variant="subtle" size="sm">{{ state || '—' }}</UBadge>
</template>
