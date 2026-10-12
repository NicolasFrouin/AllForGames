// The service worker of the web app: it keeps every file of the app in one
// cache, so the app starts without a network (an iPhone home screen app
// offline too).
//
// tool/make_service_worker.dart fills CACHE and FILES after `flutter build
// web`: a new build changes this file, so the browser installs the new
// version beside the old one, and it takes over when the page asks for it
// (index.html) or when every page of the app is closed.
const CACHE = 'afg-dev';
const FILES = [];

// The engine downloads a font for a character the bundled fonts lack.
const FONTS = 'https://fonts.gstatic.com/';

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      // Past the HTTP cache: a file of the previous version must not stay.
      cache.addAll(FILES.map((file) => new Request(file, { cache: 'no-cache' }))),
    ),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key.startsWith('afg-') && key !== CACHE)
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') self.skipWaiting();
});

// Every file of the app from this version's cache, never from another
// version: a page always runs one build. Fonts the engine downloads stay for
// the next time offline.
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  const fonts = request.url.startsWith(FONTS);
  if (url.origin !== self.location.origin && !fonts) return;
  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      const key = request.mode === 'navigate' ? new URL('./', self.location).href : request;
      const cached = await cache.match(key, { ignoreSearch: true });
      if (cached) return cached;
      const response = await fetch(request);
      if (fonts && response.ok) await cache.put(request, response.clone());
      return response;
    })(),
  );
});
