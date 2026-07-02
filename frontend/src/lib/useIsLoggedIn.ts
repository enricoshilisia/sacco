"use client";

import { useSyncExternalStore } from "react";
import { getAccessToken } from "./api";

function subscribe(callback: () => void) {
  window.addEventListener("storage", callback);
  return () => window.removeEventListener("storage", callback);
}

/**
 * Whether the browser currently holds an access token, read the
 * SSR-safe way (useSyncExternalStore) rather than setState-in-an-effect -
 * localStorage is external, browser-only state React doesn't own.
 */
export function useIsLoggedIn(): boolean {
  return useSyncExternalStore(
    subscribe,
    () => Boolean(getAccessToken()),
    () => false, // server snapshot: never "logged in" during SSR
  );
}
