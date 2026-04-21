<script setup lang="ts">
const props = defineProps<{
  kobo: number | string | null | undefined
  mono?: boolean
}>()

const { format } = useKobo()
const display = computed(() => format(props.kobo == null ? null : Number(props.kobo)))
</script>

<template>
  <span :class="{ 'font-mono tabular-nums': mono }">{{ display }}</span>
</template>
