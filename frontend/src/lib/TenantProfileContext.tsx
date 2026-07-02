"use client";

import { createContext, useContext, useEffect, useState } from "react";
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
};

type ContextValue = {
  profile: TenantProfile | null;
  status: "loading" | "ready" | "expired";
  logout: () => void;
};

const TenantProfileContext = createContext<ContextValue | null>(null);

export function TenantProfileProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [profile, setProfile] = useState<TenantProfile | null>(null);
  const [status, setStatus] = useState<"loading" | "ready" | "expired">("loading");

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace("/login");
      return;
    }
    apiFetch<TenantProfile>("/api/tenant/me/")
      .then((data) => {
        setProfile(data);
        setStatus("ready");
      })
      .catch(() => setStatus("expired"));
  }, [router]);

  function logout() {
    clearTokens();
    router.push("/login");
  }

  return (
    <TenantProfileContext.Provider value={{ profile, status, logout }}>
      {children}
    </TenantProfileContext.Provider>
  );
}

export function useTenantProfile() {
  const ctx = useContext(TenantProfileContext);
  if (!ctx) throw new Error("useTenantProfile must be used within TenantProfileProvider");
  return ctx;
}
