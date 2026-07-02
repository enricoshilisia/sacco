"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Link, useRouter } from "@/i18n/navigation";
import { apiFetch, clearTokens, getAccessToken } from "@/lib/api";
import LanguageSwitcher from "@/components/LanguageSwitcher";

type TenantProfile = {
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

export default function DashboardPage() {
  const t = useTranslations("Dashboard");
  const tNav = useTranslations("Nav");
  const router = useRouter();
  const [profile, setProfile] = useState<TenantProfile | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "expired">("loading");

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace("/login");
      return;
    }
    apiFetch<TenantProfile>("/api/tenant/me/")
      .then((data) => {
        setProfile(data);
        setState("ready");
      })
      .catch(() => setState("expired"));
  }, [router]);

  function handleLogout() {
    clearTokens();
    router.push("/login");
  }

  if (state === "loading") {
    return (
      <div className="flex min-h-full flex-1 items-center justify-center bg-primary-50">
        <p className="text-sm text-primary-600">{t("loading")}</p>
      </div>
    );
  }

  if (state === "expired" || !profile) {
    return (
      <div className="flex min-h-full flex-1 flex-col items-center justify-center gap-4 bg-primary-50 px-6 text-center">
        <p className="text-sm text-primary-700">{t("sessionExpired")}</p>
        <Link
          href="/login"
          className="rounded-full bg-primary-600 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-primary-700"
        >
          {t("backToLogin")}
        </Link>
      </div>
    );
  }

  const { tenant, user, memberships } = profile;
  const fullName = `${user.first_name} ${user.last_name}`.trim();
  const primaryMembership = memberships[0];

  return (
    <div className="flex min-h-full flex-col bg-primary-50">
      <header className="flex items-center justify-between px-4 py-4 sm:px-6">
        <span className="text-lg font-semibold text-primary-800">{tenant.name}</span>
        <div className="flex items-center gap-3">
          <LanguageSwitcher />
          <button
            onClick={handleLogout}
            className="rounded-full border border-primary-200 bg-white px-4 py-1.5 text-sm font-medium text-primary-800 hover:bg-primary-50"
          >
            {tNav("logout")}
          </button>
        </div>
      </header>

      <main className="flex-1 px-4 py-6 sm:px-6">
        <p className="mb-6 text-lg font-semibold text-primary-900">
          {t("welcome", { name: fullName || user.phone_number })}
        </p>

        <div className="grid gap-4 sm:grid-cols-2">
          <section className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100">
            <h2 className="mb-4 text-sm font-semibold uppercase tracking-wide text-primary-500">
              {t("saccoProfile")}
            </h2>
            <dl className="space-y-3 text-sm">
              <Row label={t("country")} value={tenant.country} />
              <Row label={t("currency")} value={tenant.currency} />
              <Row label={t("address")} value={tenant.address || t("notProvided")} />
              <Row label={t("contactEmail")} value={tenant.contact_email || t("notProvided")} />
              <Row label={t("contactPhone")} value={tenant.contact_phone || t("notProvided")} />
            </dl>
          </section>

          <section className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100">
            <h2 className="mb-4 text-sm font-semibold uppercase tracking-wide text-primary-500">
              {t("yourProfile")}
            </h2>
            <dl className="space-y-3 text-sm">
              <Row label={t("phoneNumber")} value={user.phone_number} />
              <Row label={t("email")} value={user.email || t("notProvided")} />
              {primaryMembership && (
                <>
                  <Row label={t("role")} value={primaryMembership.role_name} />
                  <Row
                    label={t("jobTitle")}
                    value={primaryMembership.job_title || t("notProvided")}
                  />
                </>
              )}
            </dl>
          </section>
        </div>
      </main>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-primary-500">{label}</dt>
      <dd className="text-right font-medium text-primary-900">{value}</dd>
    </div>
  );
}
