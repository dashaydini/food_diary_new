self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (_) {}
  const title = payload.title || 'BITE THE WAY';
  const options = {
    body: payload.body || 'יש עדכון חדש באפליקציה',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    dir: 'rtl',
    lang: 'he',
    tag: payload.tag || 'bite-the-way-update',
    data: { url: payload.url || '/' },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || '/', self.location.origin).href;
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then((windows) => {
      for (const windowClient of windows) {
        if ('focus' in windowClient) {
          windowClient.navigate(target);
          return windowClient.focus();
        }
      }
      return clients.openWindow ? clients.openWindow(target) : undefined;
    }));
});
