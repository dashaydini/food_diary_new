import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import webpush from 'npm:web-push@3.6.7'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const authorization = req.headers.get('Authorization')
    if (!authorization) throw new Error('Unauthorized')
    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authorization } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user || user.is_anonymous) throw new Error('Unauthorized')
    const { data: profile } = await userClient.from('profiles')
      .select('is_admin,admin_role').eq('id', user.id).single()
    if (profile?.is_admin !== true ||
        !['full_admin', 'content_admin'].includes(profile?.admin_role)) {
      throw new Error('Forbidden')
    }

    const { coupon_id } = await req.json()
    const admin = createClient(url, service)
    const { data: coupon, error: couponError } = await admin.from('coupons').select('*').eq('id', coupon_id).single()
    if (couponError) throw couponError

    const publicKey = Deno.env.get('VAPID_PUBLIC_KEY')!
    const privateKey = Deno.env.get('VAPID_PRIVATE_KEY')!
    const subject = Deno.env.get('VAPID_SUBJECT') || 'mailto:notifications@bitetheway.app'
    webpush.setVapidDetails(subject, publicKey, privateKey)

    const { data: subscriptions, error: subError } = await admin.from('push_subscriptions').select('id,subscription')
    if (subError) throw subError
    const payload = JSON.stringify({
      title: 'קופון חדש ב־BITE THE WAY',
      body: `${coupon.title} — ${coupon.business_name}`,
      tag: `coupon-${coupon.id}`,
      url: '/?open=coupons',
    })
    let sent = 0
    let failed = 0
    for (const row of subscriptions ?? []) {
      try {
        await webpush.sendNotification(row.subscription, payload)
        sent++
      } catch (error) {
        failed++
        if (error?.statusCode === 404 || error?.statusCode === 410) {
          await admin.from('push_subscriptions').delete().eq('id', row.id)
        }
      }
    }
    const now = new Date().toISOString()
    await admin.from('coupons').update({
      is_published: true,
      published_at: coupon.published_at || now,
      notification_sent_at: now,
      updated_at: now,
    }).eq('id', coupon.id)
    return Response.json({ ok: true, sent, failed }, { headers: cors })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    const status = message === 'Unauthorized' ? 401 : message === 'Forbidden' ? 403 : 400
    return Response.json({ error: message }, { status, headers: cors })
  }
})
