import { adminFetch } from '~~/server/utils/admin'

export default defineEventHandler(async (event) => {
  const q = getQuery(event)
  return await adminFetch(event, '/v1/overview/volume', { query: { days: q.days } })
})
