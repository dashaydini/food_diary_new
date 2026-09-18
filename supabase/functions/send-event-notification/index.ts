import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import webpush from 'npm:web-push@3.6.7'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
}

type EventType =
  | 'support_request'
  | 'visit_report'
  | 'image_report'
  | 'new_experience'
  | 'followed_user_experience'
  | 'experience_tag'
  | 'new_follower'

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

    const body = await req.json()
    // Older app versions may still request this event. Acknowledge it without
    // sending a push or creating a dispatch record.
    if (body.event_type === 'new_place') {
      return Response.json({ ok: true, disabled: true, sent: 0 }, { headers: cors })
    }
    const eventType = body.event_type as EventType
    const resourceId = typeof body.resource_id === 'string' ? body.resource_id : ''
    if (![
      'support_request',
      'visit_report',
      'image_report',
      'new_experience',
      'followed_user_experience',
      'experience_tag',
      'new_follower',
    ].includes(eventType) || !resourceId) {
      throw new Error('Invalid request')
    }

    const admin = createClient(url, service)
    let recipientIds: string[] = []
    let title = 'עדכון חדש ב־BITE THE WAY'
    let message = 'ממתין לך עדכון חדש באפליקציה'
    let targetUrl = '/'
    let preferenceColumn: string | null = null
    let dispatchEventType = eventType as string
    let dispatchResourceId = resourceId

    if (eventType === 'support_request') {
      const { data: item, error } = await admin.from('support_requests')
        .select('user_id,category,subject').eq('id', resourceId).single()
      if (error) throw error
      if (item.user_id !== user.id) throw new Error('Forbidden')
      const { data: admins, error: adminError } = await admin.from('profiles')
        .select('id').eq('is_admin', true).in('admin_role', ['full_admin', 'support_admin'])
      if (adminError) throw adminError
      recipientIds = (admins ?? []).map((row) => row.id)
      title = 'פנייה חדשה למנהלי האפליקציה'
      message = item.subject || 'נשלחה פנייה חדשה שממתינה לטיפול'
      targetUrl = '/?open=admin-notifications'
    } else if (eventType === 'visit_report') {
      const { data: item, error } = await admin.from('visit_reports')
        .select('reporter_id,reason').eq('id', resourceId).single()
      if (error) throw error
      if (item.reporter_id !== user.id) throw new Error('Forbidden')
      const { data: admins, error: adminError } = await admin.from('profiles')
        .select('id').eq('is_admin', true).in('admin_role', ['full_admin', 'content_admin'])
      if (adminError) throw adminError
      recipientIds = (admins ?? []).map((row) => row.id)
      title = 'דיווח חדש על חוויה'
      message = item.reason || 'חוויה הוסתרה וממתינה לבדיקת מנהל'
      targetUrl = '/?open=admin-notifications'
    } else if (eventType === 'image_report') {
      const { data: item, error } = await admin.from('visit_image_reports')
        .select('reporter_id,reason').eq('id', resourceId).single()
      if (error) throw error
      if (item.reporter_id !== user.id) throw new Error('Forbidden')
      const { data: admins, error: adminError } = await admin.from('profiles')
        .select('id').eq('is_admin', true).in('admin_role', ['full_admin', 'content_admin'])
      if (adminError) throw adminError
      recipientIds = (admins ?? []).map((row) => row.id)
      title = 'דיווח חדש על תמונה'
      message = item.reason || 'תמונה הוסתרה וממתינה לבדיקת מנהל'
      targetUrl = '/?open=admin-notifications'
    } else if (eventType === 'experience_tag') {
      const { data: item, error } = await admin.from('visit_user_tags')
        .select('user_id,visit_id,visits!visit_user_tags_visit_id_fkey(user_id,place_id,places(name),profiles!visits_user_id_fkey(display_name))')
        .eq('id', resourceId).single()
      if (error) throw error
      const visit = Array.isArray(item.visits) ? item.visits[0] : item.visits
      if (!visit || visit.user_id !== user.id) throw new Error('Forbidden')
      recipientIds = item.user_id === user.id ? [] : [item.user_id]
      const rawProfile = Array.isArray(visit.profiles) ? visit.profiles[0] : visit.profiles
      const rawPlace = Array.isArray(visit.places) ? visit.places[0] : visit.places
      const authorName = rawProfile?.display_name || 'משתמש באפליקציה'
      const placeName = rawPlace?.name || 'מקום חדש'
      title = 'תויגת בחוויה חדשה'
      message = `${authorName} צירף אותך לחוויה ב${placeName}`
      targetUrl = `/?open=tagged-experience&visit_id=${encodeURIComponent(item.visit_id)}`
      preferenceColumn = 'tags'
    } else if (eventType === 'new_follower') {
      const { data: follow, error } = await admin.from('user_follows')
        .select('follower_id,following_id')
        .eq('follower_id', user.id)
        .eq('following_id', resourceId)
        .maybeSingle()
      if (error) throw error
      if (!follow) throw new Error('Forbidden')
      const { data: profile, error: profileError } = await admin.from('profiles')
        .select('display_name').eq('id', user.id).single()
      if (profileError) throw profileError
      recipientIds = follow.following_id === user.id ? [] : [follow.following_id]
      title = 'יש לך עוקב חדש'
      message = `${profile.display_name || 'משתמש חדש'} התחיל לעקוב אחריך`
      targetUrl = `/?open=user-profile&user_id=${encodeURIComponent(user.id)}`
      preferenceColumn = 'new_followers'
      dispatchEventType = `new_follower:${user.id}`
    } else if (eventType === 'followed_user_experience') {
      const { data: visit, error } = await admin.from('visits')
        .select('user_id,place_id,created_at,moderation_status,places(name),profiles!visits_user_id_fkey(display_name)')
        .eq('id', resourceId).single()
      if (error) throw error
      if (visit.user_id !== user.id) throw new Error('Forbidden')
      if (visit.moderation_status !== 'visible' ||
          !visit.created_at ||
          Date.now() - new Date(visit.created_at).getTime() > 60 * 60 * 1000) {
        return Response.json({ ok: true, skipped: true, sent: 0 }, { headers: cors })
      }
      const { data: followers, error: followersError } = await admin
        .from('user_follows')
        .select('follower_id')
        .eq('following_id', user.id)
        .eq('notify_on_new_experience', true)
      if (followersError) throw followersError
      recipientIds = (followers ?? [])
        .map((row) => row.follower_id)
        .filter((id) => id !== user.id)
      const rawProfile = Array.isArray(visit.profiles) ? visit.profiles[0] : visit.profiles
      const rawPlace = Array.isArray(visit.places) ? visit.places[0] : visit.places
      const authorName = rawProfile?.display_name || 'משתמש באפליקציה'
      const placeName = rawPlace?.name || 'מקום חדש'
      title = `${authorName} פרסם חוויה חדשה`
      message = `חוויה חדשה ב${placeName}`
      targetUrl = `/?open=experience&visit_id=${encodeURIComponent(resourceId)}`
    } else {
      const { data: visit, error } = await admin.from('visits')
        .select('user_id,place_id,places(name)').eq('id', resourceId).single()
      if (error) throw error
      if (visit.user_id !== user.id) throw new Error('Forbidden')
      const { data: managers, error: managerError } = await admin.from('place_managers')
        .select('user_id').eq('place_id', visit.place_id).eq('status', 'active')
      if (managerError) throw managerError
      const managerIds = [...new Set((managers ?? []).map((row) => row.user_id).filter((id) => id !== user.id))]
      recipientIds = managerIds
      const rawPlace = Array.isArray(visit.places) ? visit.places[0] : visit.places
      const placeName = rawPlace?.name || 'המקום שלך'
      title = `חוויה חדשה ב${placeName}`
      message = 'נוספה חוויה חדשה למקום שלך. אפשר לצפות בה ולהגיב.'
      targetUrl = `/?open=manager-experience&place_id=${encodeURIComponent(visit.place_id)}`
      preferenceColumn = 'manager_new_experience'
    }

    recipientIds = [...new Set(recipientIds)]
    if (recipientIds.length) {
      const preferenceFields = preferenceColumn
        ? `user_id,enabled,${preferenceColumn}`
        : 'user_id,enabled'
      const { data: masterPreferences, error: masterPreferenceError } = await admin
        .from('notification_preferences')
        .select(preferenceFields)
        .in('user_id', recipientIds)
      if (masterPreferenceError) throw masterPreferenceError
      const disabledUsers = new Set((masterPreferences ?? [])
        .filter((row) => row.enabled === false ||
          (preferenceColumn && row[preferenceColumn] === false))
        .map((row) => row.user_id))
      recipientIds = recipientIds.filter((id) => !disabledUsers.has(id))
    }
    const { error: dispatchError } = await admin.from('notification_dispatches').insert({
      event_type: dispatchEventType,
      resource_id: dispatchResourceId,
      recipient_count: recipientIds.length,
    })
    if (dispatchError?.code === '23505') {
      return Response.json({ ok: true, duplicate: true, sent: 0, failed: 0 }, { headers: cors })
    }
    if (dispatchError) throw dispatchError

    const { data: subscriptions, error: subscriptionError } = recipientIds.length
      ? await admin.from('push_subscriptions').select('id,subscription').in('user_id', recipientIds)
      : { data: [], error: null }
    if (subscriptionError) throw subscriptionError

    const publicKey = Deno.env.get('VAPID_PUBLIC_KEY')!
    const privateKey = Deno.env.get('VAPID_PRIVATE_KEY')!
    const subject = Deno.env.get('VAPID_SUBJECT') || 'mailto:notifications@bitetheway.app'
    webpush.setVapidDetails(subject, publicKey, privateKey)
    const payload = JSON.stringify({
      title,
      body: message.slice(0, 180),
      tag: `${eventType}-${resourceId}`,
      url: targetUrl,
    })
    let sent = 0
    let failed = 0
    for (const row of subscriptions ?? []) {
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
    await admin.from('notification_dispatches').update({
      sent_count: sent,
      failed_count: failed,
      completed_at: new Date().toISOString(),
    }).eq('event_type', dispatchEventType).eq('resource_id', dispatchResourceId)

    return Response.json({ ok: true, recipients: recipientIds.length, sent, failed }, { headers: cors })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    const status = message === 'Unauthorized' ? 401 : message === 'Forbidden' ? 403 : 400
    return Response.json({ error: message }, { status, headers: cors })
  }
})
