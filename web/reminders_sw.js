// Shows task and medicine reminders on phones, which only allow
// notifications from a service worker. It does nothing else: no caching, no
// offline pages.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

// A reminder from the send-reminders function, sent even when the app is closed.
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }
  event.waitUntil(
    self.registration.showNotification(data.title || 'Home Checklist', {
      body: data.body || '',
      tag: data.tag,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      requireInteraction: true,
    }),
  );
});

// Tapping the notification brings the app forward, or opens it.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const w of windows) {
        if ('focus' in w) return w.focus();
      }
      return self.clients.openWindow('./');
    }),
  );
});
