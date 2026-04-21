<script setup lang="ts">
import { computed } from 'vue'

const auth = useAuthStore()
const route = useRoute()

const nav = [
  { label: 'Overview',     to: '/',              icon: 'i-lucide-layout-dashboard' },
  { label: 'Users',        to: '/users',         icon: 'i-lucide-users' },
  { label: 'Transactions', to: '/transactions',  icon: 'i-lucide-arrow-left-right' },
  { label: 'Settlements',  to: '/settlements',   icon: 'i-lucide-banknote' },
  { label: 'Fraud',        to: '/fraud',         icon: 'i-lucide-triangle-alert' },
]

const initials = computed(() => {
  const e = auth.user?.email || '?'
  return e.slice(0, 2).toUpperCase()
})

async function onLogout() {
  await auth.logout()
}
</script>

<template>
  <div class="min-h-screen grid grid-cols-[240px_1fr] bg-gray-50 dark:bg-gray-950">
    <aside class="border-r border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-4 flex flex-col gap-1">
      <div class="flex items-center gap-2 px-2 py-3 mb-2">
        <UIcon name="i-lucide-wallet" class="text-primary-500 text-xl" />
        <span class="font-semibold tracking-tight">OfflinePay</span>
        <UBadge color="neutral" variant="subtle" size="xs">backoffice</UBadge>
      </div>

      <ULink
        v-for="item in nav"
        :key="item.to"
        :to="item.to"
        active-class="bg-primary-50 dark:bg-primary-950 text-primary-600 dark:text-primary-300"
        class="flex items-center gap-2 px-3 py-2 rounded-md text-sm hover:bg-gray-100 dark:hover:bg-gray-800"
      >
        <UIcon :name="item.icon" />
        {{ item.label }}
      </ULink>

      <div class="mt-auto pt-4 border-t border-gray-200 dark:border-gray-800 flex items-center gap-3">
        <UAvatar :text="initials" size="sm" />
        <div class="flex-1 min-w-0">
          <div class="text-sm truncate">{{ auth.user?.email }}</div>
          <div class="text-xs text-gray-500 truncate">{{ auth.user?.roles?.join(', ') }}</div>
        </div>
        <UButton
          size="xs"
          color="neutral"
          variant="ghost"
          icon="i-lucide-log-out"
          :aria-label="'Log out'"
          @click="onLogout"
        />
      </div>
    </aside>

    <main class="flex flex-col overflow-hidden">
      <header class="h-14 border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 px-6 flex items-center justify-between">
        <h1 class="text-sm font-medium text-gray-600 dark:text-gray-300">
          {{ String(route.meta?.title || route.name || '') }}
        </h1>
        <div class="flex items-center gap-2">
          <UColorModeButton />
        </div>
      </header>
      <div class="p-6 overflow-auto">
        <slot />
      </div>
    </main>
  </div>
</template>
