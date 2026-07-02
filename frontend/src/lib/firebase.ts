"use client";

import { initializeApp, getApps, type FirebaseOptions } from "firebase/app";
import { getMessaging, getToken, isSupported, type Messaging } from "firebase/messaging";
import { apiFetch } from "./api";

const firebaseConfig: FirebaseOptions = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

let messagingPromise: Promise<Messaging | null> | null = null;

function getMessagingInstance() {
  if (!messagingPromise) {
    messagingPromise = isSupported().then((supported) => {
      if (!supported || !firebaseConfig.apiKey) return null;
      const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
      return getMessaging(app);
    });
  }
  return messagingPromise;
}

/**
 * Ask the browser for notification permission, mint an FCM registration
 * token for this device, and register it with the Django backend so Celery
 * push jobs can target it. Safe to call repeatedly - a no-op if unsupported
 * or Firebase isn't configured yet.
 */
export async function enablePushNotifications(): Promise<"enabled" | "denied" | "unsupported"> {
  if (typeof window === "undefined" || !("serviceWorker" in navigator)) {
    return "unsupported";
  }

  const messaging = await getMessagingInstance();
  if (!messaging) return "unsupported";

  const permission = await Notification.requestPermission();
  if (permission !== "granted") return "denied";

  const registration = await navigator.serviceWorker.register("/sw.js", {
    scope: "/",
    updateViaCache: "none",
  });
  const token = await getToken(messaging, {
    vapidKey: process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY,
    serviceWorkerRegistration: registration,
  });

  if (token) {
    await apiFetch("/api/auth/push/devices/", {
      method: "POST",
      body: JSON.stringify({ token, platform: "web" }),
    });
  }

  return "enabled";
}
