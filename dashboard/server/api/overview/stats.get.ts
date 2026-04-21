import { adminFetch } from '~~/server/utils/admin'

export default defineEventHandler(async (event) => {
  return await adminFetch(event, '/v1/overview/stats')
})
