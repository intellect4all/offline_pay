<script setup lang="ts">
defineProps<{
  label: string
  value: string | number
  sublabel?: string
  icon?: string
  trend?: 'up' | 'down' | null
}>()
</script>

<template>
  <UCard>
    <div class="flex items-start justify-between gap-3">
      <div>
        <div class="text-xs uppercase tracking-wide text-gray-500">{{ label }}</div>
        <div class="mt-1 text-2xl font-semibold">{{ value }}</div>
        <div v-if="sublabel" class="text-xs text-gray-500 mt-1">{{ sublabel }}</div>
      </div>
      <UIcon v-if="icon" :name="icon" class="text-primary-500 text-xl" />
    </div>
  </UCard>
</template>
