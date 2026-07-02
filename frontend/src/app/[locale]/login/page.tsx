"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";
import { apiFetch, setTokens } from "@/lib/api";
import { loginWithBiometrics } from "@/lib/webauthn";
import { enablePushNotifications } from "@/lib/firebase";
import LanguageSwitcher from "@/components/LanguageSwitcher";

type TokenPair = { access: string; refresh: string };

export default function LoginPage() {
  const t = useTranslations("Login");
  const router = useRouter();
  const [phoneNumber, setPhoneNumber] = useState("");
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");

  async function afterLogin() {
    // Best-effort: don't block navigation if the browser denies/unsupports push.
    enablePushNotifications().catch(() => {});
    router.push("/dashboard");
  }

  async function handlePasswordLogin(e: React.FormEvent) {
    e.preventDefault();
    setStatus("loading");
    try {
      const result = await apiFetch<TokenPair>("/api/auth/token/", {
        method: "POST",
        body: JSON.stringify({ phone_number: phoneNumber, password }),
      });
      setTokens(result.access, result.refresh);
      await afterLogin();
    } catch {
      setStatus("error");
    }
  }

  async function handleBiometricLogin() {
    if (!phoneNumber) {
      setStatus("error");
      return;
    }
    setStatus("loading");
    try {
      await loginWithBiometrics(phoneNumber);
      await afterLogin();
    } catch {
      setStatus("error");
    }
  }

  return (
    <div className="flex min-h-full flex-col bg-primary-50">
      <header className="flex items-center justify-between px-4 py-4 sm:px-6">
        <span className="text-lg font-semibold text-primary-800">{t("title")}</span>
        <LanguageSwitcher />
      </header>

      <main className="flex flex-1 items-center justify-center px-6 py-10">
        <form
          onSubmit={handlePasswordLogin}
          className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100 sm:p-8"
        >
          <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("title")}</h1>

          <label className="mb-4 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("phoneNumber")}
            </span>
            <input
              type="tel"
              required
              inputMode="tel"
              autoComplete="tel"
              placeholder="+254700000000"
              value={phoneNumber}
              onChange={(e) => setPhoneNumber(e.target.value)}
              className="w-full rounded-lg border border-primary-200 bg-white px-4 py-3 text-base text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
            />
          </label>

          <label className="mb-2 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("password")}
            </span>
            <input
              type="password"
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-lg border border-primary-200 bg-white px-4 py-3 text-base text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
            />
          </label>

          {status === "error" && (
            <p className="mb-2 text-sm text-red-600">{t("error")}</p>
          )}

          <button
            type="submit"
            disabled={status === "loading"}
            className="mt-4 w-full rounded-full bg-primary-600 px-5 py-3 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            {t("submit")}
          </button>

          <div className="my-4 flex items-center gap-3 text-xs text-primary-400">
            <span className="h-px flex-1 bg-primary-100" />
            {t("orBiometric")}
            <span className="h-px flex-1 bg-primary-100" />
          </div>

          <button
            type="button"
            onClick={handleBiometricLogin}
            disabled={status === "loading"}
            className="w-full rounded-full border border-primary-300 bg-white px-5 py-3 text-sm font-semibold text-primary-800 transition-colors hover:bg-primary-50 disabled:opacity-60"
          >
            {t("biometricLogin")}
          </button>
        </form>
      </main>
    </div>
  );
}
