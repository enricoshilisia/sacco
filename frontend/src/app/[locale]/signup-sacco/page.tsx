"use client";

import { useState } from "react";
import { useFormatter, useTranslations } from "next-intl";
import { publicApiFetch } from "@/lib/api";
import LanguageSwitcher from "@/components/LanguageSwitcher";

type SignupResult = {
  sacco_name: string;
  country: string;
  domain: string;
  trial_ends_at: string;
  status: string;
};

const inputClass =
  "w-full rounded-lg border border-primary-200 bg-white px-4 py-3 text-base text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500";

const initialForm = {
  sacco_name: "",
  country: "KE",
  address: "",
  contact_email: "",
  contact_phone: "",
  first_name: "",
  last_name: "",
  phone_number: "",
  email: "",
  job_title: "",
  password: "",
};

export default function SaccoSignupPage() {
  const t = useTranslations("SaccoSignup");
  const format = useFormatter();
  const [form, setForm] = useState(initialForm);
  const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");
  const [result, setResult] = useState<SignupResult | null>(null);

  function field(name: keyof typeof initialForm) {
    return {
      value: form[name],
      onChange: (e: React.ChangeEvent<HTMLInputElement>) =>
        setForm({ ...form, [name]: e.target.value }),
    };
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus("loading");
    try {
      const created = await publicApiFetch<SignupResult>("/api/onboarding/signup/", {
        method: "POST",
        body: JSON.stringify(form),
      });
      setResult(created);
      setStatus("idle");
    } catch {
      setStatus("error");
    }
  }

  if (result) {
    const trialEndDate = format.dateTime(new Date(result.trial_ends_at), {
      dateStyle: "long",
    });
    const loginUrl = `http://${result.domain}:3000`;

    return (
      <div className="flex min-h-full flex-col bg-primary-50">
        <header className="flex items-center justify-between px-4 py-4 sm:px-6">
          <span className="text-lg font-semibold text-primary-800">{t("title")}</span>
          <LanguageSwitcher />
        </header>
        <main className="flex flex-1 items-center justify-center px-6 py-10">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 text-center shadow-sm ring-1 ring-primary-100 sm:p-8">
            <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-primary-600 text-2xl font-bold text-white">
              ✓
            </div>
            <h1 className="text-xl font-semibold text-primary-900">{t("successTitle")}</h1>
            <p className="mt-2 text-sm leading-6 text-primary-700">
              {t("successBody", { date: trialEndDate })}
            </p>
            <p className="mt-3 rounded-lg bg-primary-50 px-3 py-2 font-mono text-sm text-primary-800">
              {result.domain}
            </p>
            <a
              href={loginUrl}
              className="mt-6 block w-full rounded-full bg-primary-600 px-5 py-3 text-center text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700"
            >
              {t("successCta")}
            </a>
          </div>
        </main>
      </div>
    );
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
          <h1 className="text-xl font-semibold text-primary-900">{t("title")}</h1>
          <p className="mt-1 mb-6 text-sm text-primary-600">{t("subtitle")}</p>

          <p className="mb-3 text-sm font-medium text-primary-800">{t("saccoSection")}</p>

          <label className="mb-4 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("saccoName")}
            </span>
            <input required className={inputClass} {...field("sacco_name")} />
          </label>

          <label className="mb-4 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("country")}
            </span>
            <select
              value={form.country}
              onChange={(e) => setForm({ ...form, country: e.target.value })}
              className={inputClass}
            >
              <option value="KE">{t("kenya")}</option>
              <option value="TZ">{t("tanzania")}</option>
            </select>
          </label>

          <label className="mb-4 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("address")}
            </span>
            <input className={inputClass} {...field("address")} />
          </label>

          <div className="mb-6 grid grid-cols-2 gap-3">
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-primary-800">
                {t("contactEmail")}
              </span>
              <input type="email" className={inputClass} {...field("contact_email")} />
            </label>
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-primary-800">
                {t("contactPhone")}
              </span>
              <input type="tel" inputMode="tel" className={inputClass} {...field("contact_phone")} />
            </label>
          </div>

          <p className="mb-3 text-sm font-medium text-primary-800">{t("ownerSection")}</p>

          <div className="mb-4 grid grid-cols-2 gap-3">
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-primary-800">
                {t("firstName")}
              </span>
              <input required className={inputClass} {...field("first_name")} />
            </label>
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-primary-800">
                {t("lastName")}
              </span>
              <input required className={inputClass} {...field("last_name")} />
            </label>
          </div>

          <label className="mb-4 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("jobTitle")}
            </span>
            <input placeholder={t("jobTitlePlaceholder")} className={inputClass} {...field("job_title")} />
          </label>

          <label className="mb-4 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("phoneNumber")}
            </span>
            <input
              type="tel"
              required
              inputMode="tel"
              placeholder="+254700000000"
              className={inputClass}
              {...field("phone_number")}
            />
          </label>

          <label className="mb-4 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("email")}
            </span>
            <input type="email" required className={inputClass} {...field("email")} />
          </label>

          <label className="mb-2 block">
            <span className="mb-1 block text-sm font-medium text-primary-800">
              {t("password")}
            </span>
            <input
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              className={inputClass}
              {...field("password")}
            />
          </label>

          {status === "error" && <p className="mb-2 text-sm text-red-600">{t("error")}</p>}

          <button
            type="submit"
            disabled={status === "loading"}
            className="mt-4 w-full rounded-full bg-primary-600 px-5 py-3 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            {t("submit")}
          </button>
        </form>
      </main>
    </div>
  );
}
