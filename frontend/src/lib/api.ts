/**
 * Thin fetch wrapper for the Django API. In this multi-tenant setup, each
 * SACCO is routed by domain (django-tenants), so NEXT_PUBLIC_API_BASE_URL
 * should point at the tenant-specific API origin (e.g.
 * http://nairobi.localhost:8000 in dev). See ../../../README.md.
 */

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

// Hits a host that matches no tenant Domain, so django-tenants falls back
// to the public schema (see PUBLIC_SCHEMA_URLCONF in backend/config/settings.py).
// Used only for SACCO sign-up, which can't be tenant-scoped by definition -
// the tenant doesn't exist yet.
const PUBLIC_API_BASE_URL =
  process.env.NEXT_PUBLIC_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

const ACCESS_TOKEN_KEY = "sacco.access_token";
const REFRESH_TOKEN_KEY = "sacco.refresh_token";

export function getAccessToken() {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(ACCESS_TOKEN_KEY);
}

export function setTokens(access: string, refresh: string) {
  window.localStorage.setItem(ACCESS_TOKEN_KEY, access);
  window.localStorage.setItem(REFRESH_TOKEN_KEY, refresh);
}

export function clearTokens() {
  window.localStorage.removeItem(ACCESS_TOKEN_KEY);
  window.localStorage.removeItem(REFRESH_TOKEN_KEY);
}

export class ApiError extends Error {
  status: number;
  body: unknown;

  constructor(status: number, body: unknown) {
    super(`API error ${status}`);
    this.status = status;
    this.body = body;
  }
}

async function baseFetch<T>(
  baseUrl: string,
  path: string,
  options: RequestInit,
  authenticated: boolean,
): Promise<T> {
  const headers = new Headers(options.headers);
  headers.set("Content-Type", "application/json");
  if (authenticated) {
    const token = getAccessToken();
    if (token) headers.set("Authorization", `Bearer ${token}`);
  }

  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });

  const isJson = response.headers.get("content-type")?.includes("application/json");
  const body = isJson ? await response.json() : await response.text();

  if (!response.ok) {
    throw new ApiError(response.status, body);
  }
  return body as T;
}

export async function apiFetch<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  return baseFetch<T>(API_BASE_URL, path, options, true);
}

/** For endpoints that must resolve to the public schema (e.g. SACCO sign-up). */
export async function publicApiFetch<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  return baseFetch<T>(PUBLIC_API_BASE_URL, path, options, false);
}
