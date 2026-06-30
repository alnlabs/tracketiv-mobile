// Sends a one-time code to verify admin logins from unknown devices.
// Deploy: supabase functions deploy send-admin-login-otp
// Secrets: WEB3FORMS_ACCESS_KEY (same as send-feedback-email)

import { createClient } from '@supabase/supabase-js'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const OTP_TTL_MINUTES = 10
const RESEND_COOLDOWN_MS = 60_000

function generateOtp(): string {
  const array = new Uint32Array(1)
  crypto.getRandomValues(array)
  return String(100_000 + (array[0] % 900_000))
}

async function hashOtp(code: string, userId: string): Promise<string> {
  const data = new TextEncoder().encode(`${code}:${userId}`)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

function maskEmail(email: string | undefined): string {
  if (!email) return 'your email'
  const [local, domain] = email.split('@')
  if (!local || !domain) return 'your email'
  const maskedLocal = local.length <= 1 ? '*' : `${local[0]}${'*'.repeat(local.length - 1)}`
  return `${maskedLocal}@${domain}`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const supabase = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: authHeader } },
    })

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser()

    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { deviceId } = await req.json()
    if (!deviceId || typeof deviceId !== 'string') {
      return new Response(JSON.stringify({ error: 'Missing deviceId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle()

    if (profileError || !profile?.is_admin) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey)

    const { data: trusted } = await serviceClient
      .from('admin_trusted_devices')
      .select('id')
      .eq('user_id', user.id)
      .eq('device_id', deviceId.trim())
      .maybeSingle()

    if (trusted) {
      return new Response(JSON.stringify({ ok: true, alreadyTrusted: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: existingOtp } = await serviceClient
      .from('admin_login_otps')
      .select('created_at')
      .eq('user_id', user.id)
      .eq('device_id', deviceId.trim())
      .maybeSingle()

    if (existingOtp?.created_at) {
      const elapsed = Date.now() - new Date(existingOtp.created_at).getTime()
      if (elapsed < RESEND_COOLDOWN_MS) {
        return new Response(
          JSON.stringify({
            error: 'Please wait before requesting another code.',
            retryAfterSeconds: Math.ceil((RESEND_COOLDOWN_MS - elapsed) / 1000),
          }),
          {
            status: 429,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        )
      }
    }

    const code = generateOtp()
    const codeHash = await hashOtp(code, user.id)
    const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000).toISOString()

    const { error: upsertError } = await serviceClient.from('admin_login_otps').upsert(
      {
        user_id: user.id,
        device_id: deviceId.trim(),
        code_hash: codeHash,
        expires_at: expiresAt,
        attempts: 0,
      },
      { onConflict: 'user_id,device_id' },
    )

    if (upsertError) {
      console.error('OTP upsert error:', upsertError)
      return new Response(JSON.stringify({ error: 'Failed to create verification code' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const web3formsKey = Deno.env.get('WEB3FORMS_ACCESS_KEY')
    if (!web3formsKey) {
      return new Response(JSON.stringify({ error: 'Email service not configured' }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const destination = user.email ?? ''
    const emailBody = [
      'A sign-in to the Tracketiv admin console was requested from an unrecognized device.',
      '',
      `Your verification code is: ${code}`,
      '',
      `This code expires in ${OTP_TTL_MINUTES} minutes.`,
      'If you did not attempt to sign in, change your password immediately.',
    ].join('\n')

    const emailResponse = await fetch('https://api.web3forms.com/submit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        access_key: web3formsKey,
        subject: '[Tracketiv Admin] Sign-in verification code',
        name: 'Tracketiv Admin',
        email: destination,
        message: emailBody,
      }),
    })

    const emailResult = await emailResponse.json()
    if (!emailResponse.ok || !emailResult.success) {
      console.error('Web3Forms error:', emailResult)
      return new Response(JSON.stringify({ error: 'Failed to send verification email' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(
      JSON.stringify({
        ok: true,
        emailHint: maskEmail(destination),
        expiresInMinutes: OTP_TTL_MINUTES,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
