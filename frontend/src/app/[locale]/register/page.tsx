"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";
import { apiFetch, setTokens } from "@/lib/api";
import LanguageSwitcher from "@/components/LanguageSwitcher";

type TokenPair = { access: string; refresh: string };

export default function RegisterPage() {
  const t = useTranslations("Home");
  const tl = useTranslations("Login");
  const router = useRouter();
  const [form, setForm] = useState({
    phone_number: "",
    first_name: "",
    last_name: "",
    password: "",
  });
  const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus("loading");
    try {
      const result = await apiFetch<TokenPair>("/api/auth/register/", {
        method: "POST",
        body: JSON.stringify(form),
      });
      setTokens(result.access, result.refresh);
      router.push("/");
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
          onSubmit={handleSubmit}
          className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100 sm:p-8"
        >
          <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("register")}</h1>

          {(["first_name", "last_name", "phone_number"] as const).map((field) => (
            <label key={field} className="mb-4 block">
              <span className="mb-1 block text-sm font-medium text-primary-800">
                {field === "phone_number" ? tl("phoneNumber") : field.replace("_", " ")}
              </span>
              <input
                required
                type={field === "phone_number" ? "tel" : "text"}
                value={form[field]}
                onChange={(e) => setForm({ ...form, [field]: e.target.value })}
                className="w-full rounded-lg border border-primary-200 px-4 py-3 text-base focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
              />
            </label>
          ))}

          <label className="mb-2 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {tl("password")}
            </span>
            <input
              required
              minLength={8}
              type="password"
              autoComplete="new-password"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              className="w-full rounded-lg border border-primary-200 px-4 py-3 text-base focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
            />
          </label>

          {status === "error" && <p className="mb-2 text-sm text-red-600">{tl("error")}</p>}

          <button
            type="submit"
            disabled={status === "loading"}
            className="mt-4 w-full rounded-full bg-primary-600 px-5 py-3 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            {t("register")}
          </button>
        </form>
      </main>
    </div>
  );
}
