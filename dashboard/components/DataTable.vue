<script setup lang="ts" generic="T">
defineProps<{
  rows: T[]
  columns: Array<{ key: string; label: string; class?: string }>
  rowLink?: (row: T) => string
  loading?: boolean
  emptyLabel?: string
}>()
</script>

<template>
  <div class="overflow-x-auto border border-gray-200 dark:border-gray-800 rounded-md bg-white dark:bg-gray-900">
    <table class="w-full text-sm">
      <thead class="bg-gray-50 dark:bg-gray-950 text-gray-500 text-xs uppercase tracking-wide">
        <tr>
          <th
            v-for="col in columns"
            :key="col.key"
            class="text-left font-medium px-4 py-2"
            :class="col.class"
          >
            {{ col.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="loading">
          <td :colspan="columns.length" class="text-center text-gray-500 py-8">Loading…</td>
        </tr>
        <tr v-else-if="!rows.length">
          <td :colspan="columns.length" class="text-center text-gray-500 py-8">
            {{ emptyLabel || 'No results' }}
          </td>
        </tr>
        <tr
          v-for="(row, i) in rows"
          v-else
          :key="i"
          class="border-t border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800/50"
          :class="{ 'cursor-pointer': rowLink }"
          @click="rowLink && $router.push(rowLink(row))"
        >
          <td v-for="col in columns" :key="col.key" class="px-4 py-2" :class="col.class">
            <slot :name="`cell-${col.key}`" :row="row">{{ (row as any)[col.key] }}</slot>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
