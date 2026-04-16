export default defineNuxtConfig({
  compatibilityDate: '2025-04-01',
  devtools: { enabled: true },
  future: { compatibilityVersion: 4 },

  modules: [
    '@nuxt/ui',
    '@pinia/nuxt',
    '@vueuse/nuxt',
    '@nuxt/icon',
  ],

  css: ['~/assets/css/main.css'],

  typescript: {
    strict: true,
    typeCheck: false,
  },

  runtimeConfig: {
    adminApiUrl: process.env.NUXT_ADMIN_API_URL || 'http://localhost:8081',
    public: {
      appName: process.env.NUXT_PUBLIC_APP_NAME || 'OfflinePay Backoffice',
    },
  },

  app: {
    head: {
      title: 'OfflinePay Backoffice',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      ],
    },
  },

  ui: {
    colorMode: true,
  },

  pinia: {
    storesDirs: ['./stores/**'],
  },
})
