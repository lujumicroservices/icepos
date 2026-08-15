self.addEventListener('push', function(event) {
  let data = {};
  try {
    if (event.data) {
      data = event.data.json();
    }
  } catch (_) {}

  const title = data.title || 'ICE POS';
  const options = {
    body: data.body || 'Tienes notificaciones pendientes.',
    tag: data.tag || 'pending-cashier-approvals',
    data: {
      url: data.url || '/',
    },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          client.focus();
          if ('navigate' in client) {
            client.navigate(targetUrl);
          }
          return;
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
      return null;
    }),
  );
});

