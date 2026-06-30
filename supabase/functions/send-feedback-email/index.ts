// Sends feedback email to alnlabs.com@gmail.com via Web3Forms.
// Deploy: supabase functions deploy send-feedback-email
// Secrets: supabase secrets set WEB3FORMS_ACCESS_KEY=your_key
// Create a form at https://web3forms.com and set the destination email to alnlabs.com@gmail.com

import { createClient } from '@supabase/supabase-js'

const FEEDBACK_TO_EMAIL = 'alnlabs.com@gmail.com'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    )

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

    const { type, message, feedbackId, contactEmail, displayName } = await req.json()

    if (!type || !message) {
      return new Response(JSON.stringify({ error: 'Missing type or message' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const web3formsKey = Deno.env.get('WEB3FORMS_ACCESS_KEY')
    if (!web3formsKey) {
      return new Response(JSON.stringify({ error: 'Email service not configured', saved: true }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const typeLabel =
      type === 'suggestion' ? 'Suggestion' : type === 'improvement' ? 'Improvement' : 'Issue'

    const emailBody = [
      `Feedback type: ${typeLabel}`,
      `From: ${displayName ?? 'Tracketiv user'}`,
      `Email: ${contactEmail ?? user.email ?? 'not provided'}`,
      feedbackId ? `Feedback ID: ${feedbackId}` : null,
      '',
      '--- Message ---',
      message,
    ]
      .filter(Boolean)
      .join('\n')

    const emailResponse = await fetch('https://api.web3forms.com/submit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        access_key: web3formsKey,
        subject: `[Tracketiv] ${typeLabel} from ${displayName ?? user.email}`,
        name: displayName ?? 'Tracketiv user',
        email: contactEmail ?? user.email ?? FEEDBACK_TO_EMAIL,
        message: emailBody,
      }),
    })

    const emailResult = await emailResponse.json()
    if (!emailResponse.ok || !emailResult.success) {
      console.error('Web3Forms error:', emailResult)
      return new Response(JSON.stringify({ error: 'Failed to send email', saved: true }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ ok: true }), {
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
