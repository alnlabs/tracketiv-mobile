// Sends FCM push when a notification row is inserted.
// Deploy: supabase functions deploy send-push-notification --no-verify-jwt
// Secrets:
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
//   supabase secrets set PUSH_WEBHOOK_SECRET=your-random-secret
// DB (once): run supabase/setup_push_notifications.sql after migration 029

import { createClient } from '@supabase/supabase-js'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-push-secret',
}

type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
}

type NotificationRecord = {
  id: string
  user_id: string
  type: string
  title: string
  body: string
  data?: Record<string, unknown>
}

function parseRecord(body: Record<string, unknown>): NotificationRecord | null {
  if (body.record && typeof body.record === 'object') {
    const record = body.record as Record<string, unknown>
    if (record.user_id && record.title && record.body) {
      return {
        id: String(record.id ?? ''),
        user_id: String(record.user_id),
        type: String(record.type ?? ''),
        title: String(record.title),
        body: String(record.body),
        data: (record.data as Record<string, unknown>) ?? {},
      }
    }
  }

  if (body.user_id && body.title && body.body) {
    return {
      id: String(body.notification_id ?? body.id ?? ''),
      user_id: String(body.user_id),
      type: String(body.type ?? ''),
      title: String(body.title),
      body: String(body.body),
      data: (body.data as Record<string, unknown>) ?? {},
    }
  }

  return null
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleaned = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const binary = atob(cleaned)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

async function getFcmAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const now = Math.floor(Date.now() / 1000)
  const claim = base64UrlEncode(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const signatureInput = new TextEncoder().encode(`${header}.${claim}`)
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, signatureInput))
  const jwt = `${header}.${claim}.${base64UrlEncode(signature)}`

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const result = await response.json()
  if (!response.ok || !result.access_token) {
    throw new Error(`Failed to get FCM access token: ${JSON.stringify(result)}`)
  }
  return result.access_token as string
}

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<{ ok: boolean; invalidToken: boolean; error?: string }> {
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: {
          priority: 'HIGH',
          notification: { channel_id: 'tracketiv_activity' },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      },
    }),
  })

  const result = await response.json()
  if (response.ok) return { ok: true, invalidToken: false }

  const message = JSON.stringify(result)
  const invalidToken =
    message.includes('UNREGISTERED') ||
    message.includes('INVALID_ARGUMENT') ||
    message.includes('NOT_FOUND')

  return { ok: false, invalidToken, error: message }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const webhookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET')
    if (webhookSecret) {
      const provided = req.headers.get('x-push-secret')
      if (provided !== webhookSecret) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
    }

    const serviceAccountRaw = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
    if (!serviceAccountRaw) {
      return new Response(JSON.stringify({ error: 'FCM not configured', skipped: true }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const serviceAccount = JSON.parse(serviceAccountRaw) as ServiceAccount
    const body = await req.json()
    const record = parseRecord(body)

    if (!record) {
      return new Response(JSON.stringify({ error: 'Invalid payload' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { data: tokens, error: tokenError } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', record.user_id)

    if (tokenError) throw tokenError
    if (!tokens?.length) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const accessToken = await getFcmAccessToken(serviceAccount)
    const dataPayload: Record<string, string> = {
      notification_id: record.id,
      type: record.type,
      title: record.title,
      body: record.body,
      ...Object.fromEntries(
        Object.entries(record.data ?? {}).map(([key, value]) => [key, String(value)]),
      ),
    }

    let sent = 0
    const invalidTokens: string[] = []

    for (const row of tokens) {
      const result = await sendFcmMessage(
        accessToken,
        serviceAccount.project_id,
        row.token,
        record.title,
        record.body,
        dataPayload,
      )

      if (result.ok) {
        sent += 1
      } else if (result.invalidToken) {
        invalidTokens.push(row.token)
      } else {
        console.error('FCM send failed:', result.error)
      }
    }

    if (invalidTokens.length > 0) {
      await supabase.from('device_tokens').delete().in('token', invalidTokens)
    }

    return new Response(JSON.stringify({ ok: true, sent, invalid: invalidTokens.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
