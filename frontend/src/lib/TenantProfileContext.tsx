"use client";

import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { useRouter } from "@/i18n/navigation";
import { apiFetch, clearTokens, getAccessToken } from "./api";

export type TenantProfile = {
  tenant: {
    name: string;
    country: string;
    currency: string;
    default_language: string;
    address: string;
    contact_email: string;
    contact_phone: string;
    logo: string | null;
    created_at: string;
  };
  user: {
    first_name: string;
    last_name: string;
    phone_number: string;
    email: string | null;
  };
  memberships: {
    role_name: string;
    job_title: string;
    is_active: boolean;
    assigned_at: string;
  }[];
  permissions: string[];
};

type ContextValue = {
  profile: TenantProfile | null;
  status: "loading" | "ready" | "expired";
  logout: () => void;
  refresh: () => void;
  /** True if the logged-in user holds this permission code in this SACCO. */
  hasPermission: (code: string) => boolean;
  /** True if the logged-in user holds any of these permission codes. */
  hasAnyPermission: (codes: string[]) => boolean;
  /** This login's own member id, if this account is linked to a member
   * record (self-service). undefined while still being checked, null once
   * confirmed there's no such link (a pure-staff account) - pages need to
   * tell those two apart to avoid flashing "forbidden" before the check
   * resolves (same undefined/null convention dashboard/page.tsx already
   * uses for its own myMember state). Nav items that should show for
   * self-service members regardless of staff permissions (Loans, Savings)
   * key off this instead of a permission code. */
  myMemberId: string | null | undefined;
};

const TenantProfileContext = createContext<ContextValue | null>(null);

export function TenantProfileProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [profile, setProfile] = useState<TenantProfile | null>(null);
  const [status, setStatus] = useState<"loading" | "ready" | "expired">("loading");
  const [myMemberId, setMyMemberId] = useState<string | null | undefined>(undefined);

  const load = useCallback(() => {
    apiFetch<TenantProfile>("/api/tenant/me/")
      .then((data) => {
        setProfile(data);
        setStatus("ready");
      })
      .catch(() => setStatus("expired"));
    // 404s for a pure-staff account with no linked member record - that's
    // expected, not an error, same as every other self-service probe in
    // this app (see dashboard/page.tsx, loans/[id]/page.tsx).
    apiFetch<{ id: string }>("/api/members/me/")
      .then((data) => setMyMemberId(data.id))
      .catch(() => setMyMemberId(null));
  }, []);

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace("/login");
      return;
    }
    load();
  }, [router, load]);

  function logout() {
    clearTokens();
    router.push("/login");
  }

  function hasPermission(code: string) {
    return profile?.permissions.includes(code) ?? false;
  }

  function hasAnyPermission(codes: string[]) {
    return codes.some(hasPermission);
  }

  return (
    <TenantProfileContext.Provider
      value={{ profile, status, logout, refresh: load, hasPermission, hasAnyPermission, myMemberId }}
    >
      {children}
    </TenantProfileContext.Provider>
  );
}

export function useTenantProfile() {
  const ctx = useContext(TenantProfileContext);
  if (!ctx) throw new Error("useTenantProfile must be used within TenantProfileProvider");
  return ctx;
}
