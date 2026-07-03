"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { apiFetch, ApiError, setTokens } from "@/lib/api";
import LanguageSwitcher from "@/components/LanguageSwitcher";

type InviteDetail = {
  member_name: string;
  member_number: string;
  existing_account: boolean;
};

type AcceptResult = {
  access: string;
  refresh: string;
};

const inputClass =
  "w-full rounded-lg border border-primary-200 bg-white px-4 py-3 text-base text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500";

export default function MemberPortalAcceptPage() {
  const t = useTranslations("MemberPortalAccept");
  const params = useParams<{ token: string }>();
  const [invite, setInvite] = useState<InviteDetail | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "invalid" | "done">("loading");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    apiFetch<InviteDetail>(`/api/members/portal-invites/${params.token}/accept/`)
      .then((data) => {
        setInvite(data);
        setState("ready");
      })
      .catch(() => setState("invalid"));
  }, [params.token]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError("");
    try {
      const result = await apiFetch<AcceptResult>(`/api/members/portal-invites/${params.token}/accept/`, {
        method: "POST",
        body: JSON.stringify({ password }),
      });
      setTokens(result.access, result.refresh);
      setState("done");
    } catch (err) {
      if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
        const detail = (err.body as { detail?: string }).detail;
        setError(detail || t("error"));
      } else {
        setError(t("error"));
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="flex min-h-full flex-col bg-primary-50">
      <header className="flex items-center justify-between px-4 py-4 sm:px-6">
        <span className="text-lg font-semibold text-primary-800">{t("title")}</span>
        <LanguageSwitcher />
      </header>

      <main className="flex flex-1 items-center justify-center px-6 py-10">
        <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100 sm:p-8">
          {state === "loading" && (
            <div className="flex justify-center py-8">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
            </div>
          )}

          {state === "invalid" && (
            <div className="text-center">
              <h1 className="text-xl font-semibold text-primary-900">{t("invalidTitle")}</h1>
              <p className="mt-2 text-sm leading-6 text-primary-600">{t("invalidBody")}</p>
            </div>
          )}

          {state === "done" && (
            <div className="text-center">
              <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-primary-600 text-2xl font-bold text-white">
                ✓
              </div>
              <h1 className="text-xl font-semibold text-primary-900">{t("successTitle")}</h1>
              <p className="mt-2 text-sm leading-6 text-primary-700">{t("successBody")}</p>
              <Link
                href="/login"
                className="mt-6 block w-full rounded-full bg-primary-600 px-5 py-3 text-center text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700"
              >
                {t("successCta")}
              </Link>
            </div>
          )}

          {state === "ready" && invite && (
            <form onSubmit={handleSubmit}>
              <h1 className="text-xl font-semibold text-primary-900">{t("title")}</h1>
              <p className="mt-1 mb-6 text-sm leading-6 text-primary-600">
                {t("welcomeBody", { name: invite.member_name, number: invite.member_number })}
              </p>

              <label className="mb-2 block">
                <span className="mb-1 block text-sm font-medium text-primary-800">
                  {invite.existing_account ? t("existingAccountPassword") : t("password")}
                </span>
                <input
                  type="password"
                  required
                  minLength={invite.existing_account ? undefined : 8}
                  autoComplete={invite.existing_account ? "current-password" : "new-password"}
                  className={inputClass}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
                <span className="mt-1 block text-xs text-primary-500">
                  {invite.existing_account ? t("existingAccountHelp") : t("passwordHelp")}
                </span>
              </label>

              {error && <p className="mb-2 text-sm text-red-600">{error}</p>}

              <button
                type="submit"
                disabled={submitting}
                className="mt-4 w-full rounded-full bg-primary-600 px-5 py-3 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                {t("submit")}
              </button>
            </form>
          )}
        </div>
      </main>
    </div>
  );
}
