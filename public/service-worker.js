// Deliberately close to doing nothing.
//
// It exists because Chrome will not offer to install a site that has no
// service worker with a fetch handler - which is why the laptop got an install
// prompt and the phone never did.
//
// It caches only Vite's hashed asset files. Those carry a content hash in the
// name, so a given URL can never mean two different things and a stale one is
// impossible. Everything else - every page, every form post, every bit of
// money - goes to the network exactly as it did before. An expense app that
// serves yesterday's balance from a cache is worse than one that says it is
// offline.
const CACHE = 'onera-assets-v1';
const IMMUTABLE = /\/vite\/assets\/[^/]+\.[0-9a-zA-Z_-]{8,}\.(js|css|woff2?|png|svg)$/;

self.addEventListener('install', (event) => {
  // Take over straight away rather than waiting for every tab to close.
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(names.filter((name) => name !== CACHE).map((name) => caches.delete(name)));
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin || !IMMUTABLE.test(url.pathname)) return;

  event.respondWith(
    (async () => {
      const cached = await caches.match(request);
      if (cached) return cached;

      const response = await fetch(request);
      // Opaque and error responses are not worth keeping.
      if (response.ok && response.type === 'basic') {
        const cache = await caches.open(CACHE);
        cache.put(request, response.clone());
      }
      return response;
    })()
  );
});
