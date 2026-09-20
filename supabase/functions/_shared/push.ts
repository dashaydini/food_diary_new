import webpush from 'npm:web-push@3.6.7'
import { JWT } from 'npm:google-auth-library@9.15.1'

export type PushPayload = {
  title: string
  body: string
  tag: string
  url: string
}

type StoredSubscription = {
  provider?: string
  token?: string
  endpoint?: string
  keys?: Record<string, string>
}

let webPushConfigured = false
let cachedFcmAccessToken: { token: string; expiresAt: number } | null = null

function configureWebPush() {
  if (webPushConfigured) return
  const publicKey = Deno.env.get('VAPID_PUBLIC_KEY')
  const privateKey = Deno.env.get('VAPID_PRIVATE_KEY')
  if (!publicKey || !privateKey) throw new Error('Web push is not configured')
  const subject = Deno.env.get('VAPID_SUBJECT') || 'mailto:notifications@bitetheway.app'
  webpush.setVapidDetails(subject, publicKey, privateKey)
  webPushConfigured = true
}

function firebaseServiceAccount() {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  if (!raw) throw new Error('FCM is not configured')
  const parsed = JSON.parse(raw)
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error('FCM service account is invalid')
  }
  return parsed as {
    project_id: string
    client_email: string
    private_key: string
  }
}

async function fcmAccessToken(serviceAccount: ReturnType<typeof firebaseServiceAccount>) {
  if (cachedFcmAccessToken && cachedFcmAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedFcmAccessToken.token
  }
  const client = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const credentials = await client.authorize()
  if (!credentials.access_token) throw new Error('Unable to authorize FCM')
  cachedFcmAccessToken = {
    token: credentials.access_token,
    expiresAt: credentials.expiry_date || Date.now() + 50 * 60_000,
  }
  return cachedFcmAccessToken.token
}

export async function sendPushNotification(
  subscription: StoredSubscription,
  payload: PushPayload,
) {
  if (subscription.provider !== 'fcm') {
    configureWebPush()
    await webpush.sendNotification(subscription, JSON.stringify(payload))
    return
  }

  if (!subscription.token) throw new Error('FCM token is missing')
  const serviceAccount = firebaseServiceAccount()
  const accessToken = await fcmAccessToken(serviceAccount)
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: subscription.token,
          notification: { title: payload.title, body: payload.body },
          data: { url: payload.url, tag: payload.tag },
          android: {
            priority: 'high',
            notification: { channel_id: 'bite_the_way_updates' },
          },
        },
      }),
    },
  )
  if (response.ok) return

  const errorBody = await response.json().catch(() => ({}))
  const details = errorBody?.error?.details
  const isUnregistered = Array.isArray(details) && details.some(
    (item: { errorCode?: string }) => item.errorCode === 'UNREGISTERED',
  )
  const error = new Error(errorBody?.error?.message || 'FCM delivery failed') as Error & {
    statusCode?: number
  }
  error.statusCode = isUnregistered ? 410 : response.status
  throw error
}
