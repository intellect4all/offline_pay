import { adminFetch } from '~~/server/utils/admin'

export default defineEventHandler(async (event) => {
  const q = getQuery(event)
  return await adminFetch(event, '/v1/settlements', {
    query: { page: q.page, per_page: q.per_page },
  })
})
