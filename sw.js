// Офлайн-кэш «Ритма кожи». Меняй VERSION при каждом выпуске.
const VERSION = 'ritm-0.3.0';
const CORE = ['./', './index.html', './styles.css', './app.js', './logic.js', './ai.js', './photos.js', './manifest.webmanifest', './icons/icon.svg', './icons/apple-touch-icon.png', './icons/icon-192.png', './icons/icon-512.png', './ritm-kozhi-default.ics'];
self.addEventListener('install', (e) => { e.waitUntil(caches.open(VERSION).then((c) => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener('activate', (e) => { e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin === location.origin) {
    // свои файлы: сначала сеть (свежая версия), при офлайне — кэш
    e.respondWith(fetch(req).then((res) => { const copy = res.clone(); caches.open(VERSION).then((c) => c.put(req, copy)); return res; }).catch(() => caches.match(req, { ignoreSearch: true }).then((r) => r || caches.match('./index.html'))));
  } else if (url.host.includes('fonts.g')) {
    // шрифты: кэш, затем сеть
    e.respondWith(caches.match(req).then((r) => r || fetch(req).then((res) => { const copy = res.clone(); caches.open(VERSION).then((c) => c.put(req, copy)); return res; })));
  }
});
