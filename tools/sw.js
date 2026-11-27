/* Trapisque Tools service worker: keeps the app working with no connection.
   Files come from the cache first and are refreshed in the background.
   Bump CACHE when shipping changes so old copies are cleared. */
var CACHE = 'trapisque-tools-v1';
var FILES = [
  './',
  'index.html',
  'styles.css',
  'data.js',
  'logic.js',
  'app.js',
  'manifest.webmanifest',
  'icons/icon.svg',
  'icons/apple-touch-icon.png',
  'icons/icon-192.png',
  'icons/icon-512.png',
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE)
      .then(function (cache) { return cache.addAll(FILES); })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (event) {
  var request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;

  var fresh = fetch(request).then(function (response) {
    if (!response || !response.ok) return response;
    var copy = response.clone();
    return caches.open(CACHE)
      .then(function (cache) { return cache.put(request, copy); })
      .then(function () { return response; });
  });
  event.waitUntil(fresh.catch(function () {}));

  event.respondWith(
    caches.match(request, { ignoreSearch: true }).then(function (cached) {
      if (cached) return cached;
      return fresh.catch(function () {
        return request.mode === 'navigate' ? caches.match('index.html') : Response.error();
      });
    })
  );
});
