"use client";

import { useSyncExternalStore } from "react";
import { isOnPublicHost } from "./api";

function subscribe() {
  // The host doesn't change during a component's lifetime (only a full
  // page navigation changes it, which remounts everything anyway), so
  // there's nothing to subscribe to - this just satisfies
  // useSyncExternalStore's signature.
  return () => {};
}

/**
 * SSR-safe read of isOnPublicHost() (useSyncExternalStore, same pattern as
 * useIsLoggedIn) - calling isOnPublicHost() directly in a component body
 * would return false on the server (no window) and the real value on the
 * client's first render, which is exactly the hydration-mismatch React
 * warns about.
 */
export function useIsOnPublicHost(): boolean {
  return useSyncExternalStore(
    subscribe,
    () => isOnPublicHost(),
    () => false, // server snapshot: never "on the public host" during SSR
  );
}
