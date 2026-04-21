import { H3Event, getCookie, setCookie, deleteCookie, createError } from 'h3'

const ACCESS_COOKIE = 'op_access'
const REFRESH_COOKIE = 'op_refresh'

interface LoginResponse {
  access_token: string
  refresh_token: string
  expires_at: string
  refresh_expires_at: string
  user: {
    id: string
    email: string
    full_name: string
    roles: string[]
  }
}

export function adminApiBase(): string {
  return useRuntimeConfig().adminApiUrl
}

function cookieOpts(event: H3Event, maxAgeSec: number) {
  return {
    httpOnly: true,
    sameSite: 'lax' as const,
    secure: !import.meta.dev,
    path: '/',
    maxAge: maxAgeSec,
  }
}

export function storeSession(event: H3Event, res: LoginResponse) {
  const accessMaxAge = Math.max(60, Math.floor((new Date(res.expires_at).getTime() - Date.now()) / 1000))
  const refreshMaxAge = Math.max(60, Math.floor((new Date(res.refresh_expires_at).getTime() - Date.now()) / 1000))
  setCookie(event, ACCESS_COOKIE, res.access_token, cookieOpts(event, accessMaxAge))
  setCookie(event, REFRESH_COOKIE, res.refresh_token, cookieOpts(event, refreshMaxAge))
}

export function clearSession(event: H3Event) {
  deleteCookie(event, ACCESS_COOKIE, { path: '/' })
  deleteCookie(event, REFRESH_COOKIE, { path: '/' })
}

export function accessToken(event: H3Event): string | undefined {
  return getCookie(event, ACCESS_COOKIE)
}

export function refreshToken(event: H3Event): string | undefined {
  return getCookie(event, REFRESH_COOKIE)
}

/**
 * adminFetch forwards an authenticated request to the admin REST API,
 * transparently refreshing the access token on 401 using the refresh cookie.
 */
export async function adminFetch<T = unknown>(
  event: H3Event,
  path: string,
  init: { method?: string; body?: unknown; query?: Record<string, unknown> } = {},
): Promise<T> {
  const base = adminApiBase()
  const call = (tok: string | undefined) =>
    $fetch<T>(`${base}${path}`, {
      method: init.method as any,
      body: init.body,
      query: init.query,
      headers: tok ? { Authorization: `Bearer ${tok}` } : {},
    })

  try {
    return await call(accessToken(event))
  } catch (err: any) {
    if (err?.statusCode !== 401) throw err
    const refresh = refreshToken(event)
    if (!refresh) throw createError({ statusCode: 401, statusMessage: 'not authenticated' })
    const refreshed = await $fetch<LoginResponse>(`${base}/v1/auth/refresh`, {
      method: 'POST',
      body: { refresh_token: refresh },
    }).catch(() => null)
    if (!refreshed) {
      clearSession(event)
      throw createError({ statusCode: 401, statusMessage: 'session expired' })
    }
    storeSession(event, refreshed)
    return call(refreshed.access_token)
  }
}

export async function login(event: H3Event, email: string, password: string) {
  const res = await $fetch<LoginResponse>(`${adminApiBase()}/v1/auth/login`, {
    method: 'POST',
    body: { email, password },
  })
  storeSession(event, res)
  return res.user
}

export async function logout(event: H3Event) {
  const refresh = refreshToken(event)
  if (refresh) {
    await $fetch(`${adminApiBase()}/v1/auth/logout`, {
      method: 'POST',
      body: { refresh_token: refresh },
    }).catch(() => null)
  }
  clearSession(event)
}
