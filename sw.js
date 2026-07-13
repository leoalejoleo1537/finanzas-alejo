// Service worker mínimo — habilita "instalar" como PWA.
// Fase 0: sin caché agresivo (para no servir datos viejos). El tiempo real
// vive en Supabase; aquí solo dejamos la app instalable.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => { /* passthrough: siempre red */ });
