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
    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
    })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user || user.is_anonymous) throw new Error('Unauthorized')

    const { data: profile } = await userClient.from('profiles')
      .select('is_admin,admin_role').eq('id', user.id).single()
    if (profile?.is_admin !== true || profile?.admin_role !== 'full_admin') {
      throw new Error('Forbidden')
    }

    const input = await req.json()
    const title = typeof input.title === 'string' ? input.title.trim() : ''
    const body = typeof input.body === 'string' ? input.body.trim() : ''
    const targetUrl = input.target_url === '/?open=coupons'
      ? '/?open=coupons'
      : '/'
    if (title.length < 3 || title.length > 80 || body.length < 5 || body.length > 240) {
      throw new Error('Invalid message')
    }

    const admin = createClient(url, service)
    const { data: subscriptions, error: subscriptionError } = await admin
      .from('push_subscriptions').select('id,user_id,subscription')
    if (subscriptionError) throw subscriptionError
    const userIds = [...new Set((subscriptions ?? []).map((row) => row.user_id))]
    const { data: preferences, error: preferencesError } = userIds.length
      ? await admin.from('notification_preferences')
        .select('user_id,enabled,system_messages').in('user_id', userIds)
      : { data: [], error: null }
    if (preferencesError) throw preferencesError
    const disabledUsers = new Set((preferences ?? [])
      .filter((row) => row.enabled === false || row.system_messages === false)
      .map((row) => row.user_id))
    const eligibleSubscriptions = (subscriptions ?? [])
      .filter((row) => !disabledUsers.has(row.user_id))
    const recipientCount = new Set(eligibleSubscriptions.map((row) => row.user_id)).size
    const { data: notification, error: createError } = await admin
      .from('system_notifications')
      .insert({
        title,
        body,
        target_url: targetUrl,
        created_by: user.id,
        recipient_count: recipientCount,
      })
      .select('id')
      .single()
    if (createError) throw createError

    const publicKey = Deno.env.get('VAPID_PUBLIC_KEY')!
    const privateKey = Deno.env.get('VAPID_PRIVATE_KEY')!
    const subject = Deno.env.get('VAPID_SUBJECT') || 'mailto:notifications@bitetheway.app'
    webpush.setVapidDetails(subject, publicKey, privateKey)
    const payload = JSON.stringify({
      title,
      body,
      tag: `system-${notification.id}`,
      url: targetUrl,
    })

    let sent = 0
    let failed = 0
    for (const row of eligibleSubscriptions) {
      try {
        await webpush.sendNotification(row.subscription, payload)
        sent++
      } catch (error) {
        failed++
        const statusCode = (error as { statusCode?: number })?.statusCode
        if (statusCode === 404 || statusCode === 410) {
          await admin.from('push_subscriptions').delete().eq('id', row.id)
        }
      }
    }

    await admin.from('system_notifications').update({
      status: failed > 0 && sent === 0 ? 'failed' : 'sent',
      sent_count: sent,
      failed_count: failed,
      completed_at: new Date().toISOString(),
    }).eq('id', notification.id)

    return Response.json({
      ok: true,
      notification_id: notification.id,
      recipients: recipientCount,
      sent,
      failed,
    }, { headers: cors })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    const status = message === 'Unauthorized' ? 401 : message === 'Forbidden' ? 403 : 400
    return Response.json({ error: message }, { status, headers: cors })
  }
})
