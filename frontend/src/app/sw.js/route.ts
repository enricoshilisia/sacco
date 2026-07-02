// Served at /sw.js. Written by hand rather than via a bundler plugin:
// Next.js 16 defaults to Turbopack for both `dev` and `build`, and
// community PWA/service-worker plugins (next-pwa, Serwist) still require a
// webpack config hook, so they silently no-op under Turbopack. See
// node_modules/next/dist/docs/01-app/02-guides/progressive-web-apps.md,
// which recommends a hand-written public/sw.js for exactly this reason.
//
// This single service worker does two jobs: a minimal offline app-shell
// cache, and the Firebase Cloud Messaging background push handler.

export async function GET() {
  const firebaseConfig = {
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? "",
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ?? "",
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? "",
    messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID ?? "",
    appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID ?? "",
  };

  const body = `
const CACHE_NAME = "sacco-shell-v1";
const APP_SHELL = ["/", "/manifest.webmanifest", "/icons/icon-192.png", "/icons/icon-512.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    )
  );
  self.clients.claim();
});

// Network-first for navigations (so users get fresh content while online),
// falling back to the cached shell when offline.
self.addEventListener("fetch", (event) => {
  if (event.request.mode === "navigate") {
    event.respondWith(
      fetch(event.request).catch(() => caches.match("/"))
    );
  }
});

// --- Firebase Cloud Messaging (background push) ---
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

if (${JSON.stringify(Boolean(firebaseConfig.apiKey))}) {
  firebase.initializeApp(${JSON.stringify(firebaseConfig)});
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const { title, body, icon } = payload.notification || {};
    self.registration.showNotification(title || "SACCO Platform", {
      body: body || "",
      icon: icon || "/icons/icon-192.png",
    });
  });
}
`.trim();

  return new Response(body, {
    headers: {
      "Content-Type": "application/javascript; charset=utf-8",
      "Service-Worker-Allowed": "/",
    },
  });
}
