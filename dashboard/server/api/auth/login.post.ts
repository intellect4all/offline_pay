import { login } from '~~/server/utils/admin'

export default defineEventHandler(async (event) => {
  const body = await readBody<{ email: string; password: string }>(event)
  if (!body?.email || !body?.password) {
    throw createError({ statusCode: 400, statusMessage: 'email and password required' })
  }
  return await login(event, body.email, body.password)
})
