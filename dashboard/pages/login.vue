<script setup lang="ts">
definePageMeta({ layout: false })

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref<string | null>(null)

async function submit() {
  error.value = null
  try {
    await auth.login(email.value, password.value)
    const next = (route.query.next as string) || '/'
    await router.push(next)
  } catch (e: any) {
    error.value = e?.data?.statusMessage || e?.statusMessage || 'Login failed'
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950 p-4">
    <UCard class="w-full max-w-sm">
      <template #header>
        <div class="flex items-center gap-2">
          <UIcon name="i-lucide-wallet" class="text-primary-500 text-xl" />
          <div>
            <div class="font-semibold">OfflinePay</div>
            <div class="text-xs text-gray-500">Backoffice sign-in</div>
          </div>
        </div>
      </template>

      <form class="space-y-4" @submit.prevent="submit">
        <UFormField label="Email" required>
          <UInput v-model="email" type="email" autocomplete="email" autofocus />
        </UFormField>
        <UFormField label="Password" required>
          <UInput v-model="password" type="password" autocomplete="current-password" />
        </UFormField>
        <UAlert v-if="error" color="error" variant="subtle" :title="error" icon="i-lucide-triangle-alert" />
        <UButton type="submit" block :loading="auth.loading" icon="i-lucide-log-in">Sign in</UButton>
      </form>
    </UCard>
  </div>
</template>
