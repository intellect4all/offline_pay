import { adminFetch } from '~~/server/utils/admin'

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id')
  return await adminFetch(event, `/v1/users/${id}`)
})
