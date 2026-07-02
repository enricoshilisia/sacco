/**
 * Thin fetch wrapper for the Django API. Each SACCO is routed by domain
 * (django-tenants), and this frontend can be reached at several different
 * hostnames for the same tenant (nairobi.localhost, nairobi.<ip>.nip.io,
 * a future real domain, ...). Rather than pin the API target to one tenant
 * via a static env var, the API base is derived from whatever hostname the
 * browser is actually on right now - so visiting the "dar" subdomain talks
 * to the "dar" backend automatically, with no per-tenant env var to update.
 * NEXT_PUBLIC_API_BASE_URL still works as an explicit override if set.
 */

function resolveApiBaseUrl(): string {
  if (process.env.NEXT_PUBLIC_API_BASE_URL) {
    return process.env.NEXT_PUBLIC_API_BASE_URL;
  }
  if (typeof window !== "undefined") {
    const port = process.env.NEXT_PUBLIC_API_PORT ?? "8000";
    return `${window.location.protocol}//${window.location.hostname}:${port}`;
  }
  return "http://localhost:8000";
}

// Hits a host that matches no tenant Domain, so django-tenants falls back
// to the public schema (see PUBLIC_SCHEMA_URLCONF in backend/config/settings.py).
// Used only for SACCO sign-up, which can't be tenant-scoped by definition -
// the tenant doesn't exist yet. Unlike the tenant API base, this can't be
// derived from the current hostname (that hostname might itself BE a
// tenant's domain), so it stays an explicit env var.
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
  return baseFetch<T>(resolveApiBaseUrl(), path, options, true);
}

/** For endpoints that must resolve to the public schema (e.g. SACCO sign-up). */
export async function publicApiFetch<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  return baseFetch<T>(PUBLIC_API_BASE_URL, path, options, false);
}
