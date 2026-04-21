import { defineStore } from 'pinia'

export interface AdminUser {
  id: string
  email: string
  full_name?: string
  roles: string[]
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null as AdminUser | null,
    loading: false as boolean,
  }),

  getters: {
    isAuthenticated: (s) => !!s.user,
    hasRole: (s) => (role: string) => !!s.user?.roles.includes(role),
    hasAnyRole: (s) => (roles: string[]) => !!s.user?.roles.some((r) => roles.includes(r)),
  },

  actions: {
    async login(email: string, password: string) {
      this.loading = true
      try {
        const user = await $fetch<AdminUser>('/api/auth/login', {
          method: 'POST',
          body: { email, password },
        })
        this.user = user
        return user
      } finally {
        this.loading = false
      }
    },

    async fetchMe() {
      try {
        const fetcher = import.meta.server ? useRequestFetch() : $fetch
        this.user = await fetcher<AdminUser>('/api/auth/me')
      } catch {
        this.user = null
      }
    },

    async logout() {
      try {
        await $fetch('/api/auth/logout', { method: 'POST' })
      } catch { /* ignore */ }
      this.user = null
      await navigateTo('/login')
    },
  },
})
