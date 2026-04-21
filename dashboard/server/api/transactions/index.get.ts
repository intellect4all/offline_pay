import { adminFetch } from '~~/server/utils/admin'

export default defineEventHandler(async (event) => {
  const q = getQuery(event)
  return await adminFetch(event, '/v1/transactions', {
    query: {
      state: q.state, payer: q.payer, payee: q.payee,
      page: q.page, per_page: q.per_page,
    },
  })
})
