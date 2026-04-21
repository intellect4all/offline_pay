import { logout } from '~~/server/utils/admin'

export default defineEventHandler(async (event) => {
  await logout(event)
  return { ok: true }
})
