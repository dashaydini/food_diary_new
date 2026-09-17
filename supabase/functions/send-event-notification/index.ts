import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import webpush from 'npm:web-push@3.6.7'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
}

function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const radians = Math.PI / 180
  const deltaLat = (lat2 - lat1) * radians
  const deltaLon = (lon2 - lon1) * radians
  const a = Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1 * radians) * Math.cos(lat2 * radians) * Math.sin(deltaLon / 2) ** 2
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

type EventType =
  | 'support_request'
  | 'visit_report'
  | 'image_report'
  | 'new_experience'
  | 'experience_tag'
  | 'new_follower'
  | 'new_place'

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
    const eventType = body.event_type as EventType
    const resourceId = typeof body.resource_id === 'string' ? body.resource_id : ''
    if (![
      'support_request',
      'visit_report',
      'image_report',
      'new_experience',
      'experience_tag',
      'new_follower',
      'new_place',
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
    } else if (eventType === 'new_place') {
      const { data: place, error } = await admin.from('places')
        .select('user_id,name,address,category_id,latitude,longitude').eq('id', resourceId).single()
      if (error) throw error
      if (place.user_id !== user.id) throw new Error('Forbidden')
      const { data: subscriberRows, error: subscriberError } = await admin
        .from('push_subscriptions').select('user_id')
      if (subscriberError) throw subscriberError
      const subscriberIds = [...new Set((subscriberRows ?? [])
        .map((row) => row.user_id)
        .filter((id) => id && id !== user.id))]
      const placeLat = Number(place.latitude)
      const placeLon = Number(place.longitude)
      // An enabled switch does not mean "alert me about every place". Notify
      // only people who actually visited the same category nearby. Historic
      // visits in multiple regions count; the user's current GPS is irrelevant.
      if (subscriberIds.length && place.latitude != null && place.longitude != null &&
          Number.isFinite(placeLat) && Number.isFinite(placeLon) && place.category_id) {
        const matched = new Set<string>()
        for (let offset = 0; ; offset += 1000) {
          const { data: visits, error: visitError } = await admin.from('visits')
            .select('user_id,places!inner(category_id,latitude,longitude)')
            .in('user_id', subscriberIds)
            .eq('places.category_id', place.category_id)
            .range(offset, offset + 999)
          if (visitError) throw visitError
          for (const visit of visits ?? []) {
            const visitedPlace = Array.isArray(visit.places) ? visit.places[0] : visit.places
            if (visitedPlace?.latitude == null || visitedPlace?.longitude == null) continue
            const latitude = Number(visitedPlace.latitude)
            const longitude = Number(visitedPlace.longitude)
            if (Number.isFinite(latitude) && Number.isFinite(longitude) &&
                distanceKm(placeLat, placeLon, latitude, longitude) <= 40) {
              matched.add(visit.user_id)
            }
          }
          if (!visits || visits.length < 1000) break
        }
        recipientIds = [...matched]
      }
      title = 'מקום חדש ב־BITE THE WAY'
      message = place.address ? `${place.name} — ${place.address}` : place.name
      targetUrl = `/?open=place&place_id=${encodeURIComponent(resourceId)}`
      preferenceColumn = 'new_places_ai'
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
