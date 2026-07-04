"use client";

import { useEffect, useRef, useState } from "react";
import { useLocale, useTranslations } from "next-intl";
import {
  Building2,
  Check,
  Copy,
  Hash,
  ImagePlus,
  Save,
  ShieldCheck,
  Smartphone,
  UserPlus,
  Users,
  XCircle,
} from "lucide-react";
import { apiFetch, ApiError } from "@/lib/api";
import { copyToClipboard } from "@/lib/clipboard";
import { useTenantProfile } from "@/lib/TenantProfileContext";

type TenantConfig = {
  default_language: string;
  allowed_id_types: string[];
  member_number_prefix: string;
  member_number_suffix: string;
  member_number_padding: number;
  member_number_next_sequence: number;
  active_sms_provider: string;
  active_payment_provider: string;
  active_crb_provider: string;
};

type LoanProductOption = { id: string; name: string };

type LoanEligibilityPolicy = {
  is_active: boolean;
  require_kyc_verified: boolean;
  require_no_active_arrears: boolean;
  max_active_loans: number | null;
  min_membership_months: number;
  min_guarantor_coverage_ratio: string | null;
  require_crb_check: boolean;
  crb_deny_below_score: number | null;
  crb_refer_below_score: number | null;
};

const DEFAULT_POLICY: LoanEligibilityPolicy = {
  is_active: true,
  require_kyc_verified: true,
  require_no_active_arrears: true,
  max_active_loans: null,
  min_membership_months: 0,
  min_guarantor_coverage_ratio: null,
  require_crb_check: false,
  crb_deny_below_score: null,
  crb_refer_below_score: null,
};

type TenantProfile = {
  name: string;
  address: string;
  contact_email: string;
  contact_phone: string;
  logo: string | null;
};

const ID_TYPES = ["NATIONAL_ID", "HUDUMA", "NIDA", "PASSPORT"] as const;

const inputClass =
  "w-full rounded-lg border border-primary-200 bg-white px-4 py-3 text-base text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500";

const TABS = [
  { key: "sacco", icon: Building2 },
  { key: "numbering", icon: Hash },
  { key: "providers", icon: Smartphone },
  { key: "loanEligibility", icon: ShieldCheck },
  { key: "staff", icon: Users },
] as const;

type TabKey = (typeof TABS)[number]["key"];

export default function SettingsPage() {
  const t = useTranslations("Settings");
  const [tab, setTab] = useState<TabKey>("sacco");

  return (
    <div className={tab === "staff" ? "mx-auto max-w-4xl" : "mx-auto max-w-2xl"}>
      <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("title")}</h1>

      <div className="mb-6 flex gap-1 border-b border-primary-100">
        {TABS.map(({ key, icon: Icon }) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
            className={
              "flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-medium transition-colors " +
              (tab === key
                ? "border-primary-600 text-primary-700"
                : "border-transparent text-primary-500 hover:text-primary-700")
            }
          >
            <Icon size={16} />
            {t(`tab_${key}`)}
          </button>
        ))}
      </div>

      {tab === "sacco" && <SaccoDetailsSection />}
      {tab === "numbering" && <MemberNumberingSection />}
      {tab === "providers" && <ProvidersSection />}
      {tab === "loanEligibility" && <LoanEligibilitySection />}
      {tab === "staff" && <StaffSection />}
    </div>
  );
}

function SaccoDetailsSection() {
  const t = useTranslations("Settings");
  const { refresh } = useTenantProfile();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [profile, setProfile] = useState<TenantProfile | null>(null);
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [logoPreview, setLogoPreview] = useState<string | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");

  useEffect(() => {
    apiFetch<TenantProfile>("/api/tenant/profile/")
      .then((data) => {
        setProfile(data);
        setState("ready");
      })
      .catch(() => setState("forbidden"));
  }, []);

  function handleLogoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setLogoFile(file);
    setLogoPreview(URL.createObjectURL(file));
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!profile) return;
    setSaveState("saving");
    try {
      const form = new FormData();
      form.append("name", profile.name);
      form.append("address", profile.address);
      form.append("contact_email", profile.contact_email);
      form.append("contact_phone", profile.contact_phone);
      if (logoFile) form.append("logo", logoFile);

      const updated = await apiFetch<TenantProfile>("/api/tenant/profile/", {
        method: "PATCH",
        body: form,
      });
      setProfile(updated);
      setLogoFile(null);
      setSaveState("saved");
      refresh();
      setTimeout(() => setSaveState("idle"), 2000);
    } catch {
      setSaveState("error");
    }
  }

  if (state === "loading") {
    return (
      <div className="mb-6 flex justify-center rounded-2xl bg-white py-12 shadow-sm ring-1 ring-primary-100/80">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "forbidden" || !profile) {
    return (
      <div className="mb-6 rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSave} className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
      <h2 className="mb-5 text-sm font-semibold text-primary-900">{t("saccoDetails")}</h2>

      <div className="mb-5 flex items-center gap-4">
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          className="group relative flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary-50 text-primary-400 ring-1 ring-primary-100"
        >
          {logoPreview || profile.logo ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={logoPreview ?? profile.logo ?? ""} alt="" className="h-full w-full object-cover" />
          ) : (
            <Building2 size={24} />
          )}
          <span className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 transition-opacity group-hover:opacity-100">
            <ImagePlus size={18} className="text-white" />
          </span>
        </button>
        <div>
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="text-sm font-medium text-primary-700 hover:underline"
          >
            {t("changeLogo")}
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={handleLogoChange}
          />
        </div>
      </div>

      <label className="mb-4 block">
        <span className="mb-1 block text-sm font-medium text-primary-800">{t("saccoName")}</span>
        <input
          required
          className={inputClass}
          value={profile.name}
          onChange={(e) => setProfile({ ...profile, name: e.target.value })}
        />
      </label>

      <label className="mb-4 block">
        <span className="mb-1 block text-sm font-medium text-primary-800">{t("address")}</span>
        <input
          className={inputClass}
          value={profile.address}
          onChange={(e) => setProfile({ ...profile, address: e.target.value })}
        />
      </label>

      <div className="mb-2 grid grid-cols-2 gap-3">
        <label className="block">
          <span className="mb-1 block text-sm font-medium text-primary-800">{t("contactEmail")}</span>
          <input
            type="email"
            className={inputClass}
            value={profile.contact_email}
            onChange={(e) => setProfile({ ...profile, contact_email: e.target.value })}
          />
        </label>
        <label className="block">
          <span className="mb-1 block text-sm font-medium text-primary-800">{t("contactPhone")}</span>
          <input
            type="tel"
            className={inputClass}
            value={profile.contact_phone}
            onChange={(e) => setProfile({ ...profile, contact_phone: e.target.value })}
          />
        </label>
      </div>

      {saveState === "error" && <p className="mb-2 mt-3 text-sm text-red-600">{t("error")}</p>}

      <button
        type="submit"
        disabled={saveState === "saving"}
        className="mt-4 inline-flex items-center gap-2 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
      >
        <Save size={16} />
        {saveState === "saved" ? t("saved") : t("save")}
      </button>
    </form>
  );
}

function MemberNumberingSection() {
  const t = useTranslations("Settings");
  const [config, setConfig] = useState<TenantConfig | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");

  useEffect(() => {
    apiFetch<TenantConfig>("/api/settings/")
      .then((data) => {
        setConfig(data);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 403) setState("forbidden");
        else setState("forbidden");
      });
  }, []);

  function toggleIdType(idType: string) {
    if (!config) return;
    const has = config.allowed_id_types.includes(idType);
    setConfig({
      ...config,
      allowed_id_types: has
        ? config.allowed_id_types.filter((t) => t !== idType)
        : [...config.allowed_id_types, idType],
    });
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!config) return;
    setSaveState("saving");
    try {
      const updated = await apiFetch<TenantConfig>("/api/settings/", {
        method: "PATCH",
        body: JSON.stringify({
          default_language: config.default_language,
          allowed_id_types: config.allowed_id_types,
          member_number_prefix: config.member_number_prefix,
          member_number_suffix: config.member_number_suffix,
          member_number_padding: config.member_number_padding,
        }),
      });
      setConfig(updated);
      setSaveState("saved");
      setTimeout(() => setSaveState("idle"), 2000);
    } catch {
      setSaveState("error");
    }
  }

  if (state === "loading") {
    return (
      <div className="mb-6 flex justify-center rounded-2xl bg-white py-12 shadow-sm ring-1 ring-primary-100/80">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "forbidden" || !config) {
    return (
      <div className="mb-6 rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  const previewNumber =
    `${config.member_number_prefix}` +
    `${String(config.member_number_next_sequence).padStart(config.member_number_padding, "0")}` +
    `${config.member_number_suffix}`;

  return (
    <form onSubmit={handleSave}>
      <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <h2 className="mb-1 text-sm font-semibold text-primary-900">{t("memberNumbering")}</h2>
        <p className="mb-4 text-sm text-primary-500">{t("memberNumberingHelp")}</p>

        <div className="mb-4 grid grid-cols-3 gap-3">
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("prefix")}</span>
            <input
              className={inputClass}
              value={config.member_number_prefix}
              maxLength={20}
              placeholder={t("optional")}
              onChange={(e) => setConfig({ ...config, member_number_prefix: e.target.value })}
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("suffix")}</span>
            <input
              className={inputClass}
              value={config.member_number_suffix}
              maxLength={20}
              placeholder={t("optional")}
              onChange={(e) => setConfig({ ...config, member_number_suffix: e.target.value })}
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("padding")}</span>
            <input
              type="number"
              min={1}
              max={10}
              className={inputClass}
              value={config.member_number_padding}
              onChange={(e) =>
                setConfig({ ...config, member_number_padding: Number(e.target.value) || 1 })
              }
            />
          </label>
        </div>

        <div className="rounded-lg bg-primary-50 px-4 py-3 text-sm">
          <span className="text-primary-600">{t("nextNumberPreview")}: </span>
          <span
            data-testid="member-number-preview"
            className="font-mono font-semibold text-primary-900"
          >
            {previewNumber}
          </span>
        </div>
      </div>

      <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <h2 className="mb-1 text-sm font-semibold text-primary-900">{t("allowedIdTypes")}</h2>
        <p className="mb-4 text-sm text-primary-500">{t("allowedIdTypesHelp")}</p>
        <div className="grid grid-cols-2 gap-3">
          {ID_TYPES.map((idType) => (
            <label
              key={idType}
              className="flex items-center gap-2.5 rounded-lg border border-primary-100 px-4 py-3 text-sm text-primary-800"
            >
              <input
                type="checkbox"
                checked={config.allowed_id_types.includes(idType)}
                onChange={() => toggleIdType(idType)}
                className="h-4 w-4 rounded border-primary-300 text-primary-600 focus:ring-primary-500"
              />
              {t(`idType_${idType}`)}
            </label>
          ))}
        </div>
      </div>

      {saveState === "error" && <p className="mb-4 text-sm text-red-600">{t("error")}</p>}

      <button
        type="submit"
        disabled={saveState === "saving"}
        className="inline-flex items-center gap-2 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
      >
        <Save size={16} />
        {saveState === "saved" ? t("saved") : t("save")}
      </button>
    </form>
  );
}

const SMS_PROVIDER_OPTIONS = ["", "africastalking", "beem"] as const;
const PAYMENT_PROVIDER_OPTIONS = ["", "daraja", "selcom"] as const;
const CRB_PROVIDER_OPTIONS = ["", "mock"] as const;

function ProvidersSection() {
  const t = useTranslations("Settings");
  const [config, setConfig] = useState<TenantConfig | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");

  useEffect(() => {
    apiFetch<TenantConfig>("/api/settings/")
      .then((data) => {
        setConfig(data);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 403) setState("forbidden");
        else setState("forbidden");
      });
  }, []);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!config) return;
    setSaveState("saving");
    try {
      const updated = await apiFetch<TenantConfig>("/api/settings/", {
        method: "PATCH",
        body: JSON.stringify({
          active_sms_provider: config.active_sms_provider,
          active_payment_provider: config.active_payment_provider,
          active_crb_provider: config.active_crb_provider,
        }),
      });
      setConfig(updated);
      setSaveState("saved");
      setTimeout(() => setSaveState("idle"), 2000);
    } catch {
      setSaveState("error");
    }
  }

  if (state === "loading") {
    return (
      <div className="mb-6 flex justify-center rounded-2xl bg-white py-12 shadow-sm ring-1 ring-primary-100/80">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "forbidden" || !config) {
    return (
      <div className="mb-6 rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSave}>
      <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <h2 className="mb-1 text-sm font-semibold text-primary-900">{t("providers")}</h2>
        <p className="mb-4 text-sm text-primary-500">{t("providersHelp")}</p>

        <div className="grid grid-cols-2 gap-3">
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("smsProvider")}</span>
            <select
              value={config.active_sms_provider}
              onChange={(e) => setConfig({ ...config, active_sms_provider: e.target.value })}
              className={inputClass}
            >
              {SMS_PROVIDER_OPTIONS.map((code) => (
                <option key={code} value={code}>
                  {code === "" ? t("providerMock") : t(`smsProvider_${code}`)}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("paymentProvider")}</span>
            <select
              value={config.active_payment_provider}
              onChange={(e) => setConfig({ ...config, active_payment_provider: e.target.value })}
              className={inputClass}
            >
              {PAYMENT_PROVIDER_OPTIONS.map((code) => (
                <option key={code} value={code}>
                  {code === "" ? t("providerMock") : t(`paymentProvider_${code}`)}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("crbProvider")}</span>
            <select
              value={config.active_crb_provider}
              onChange={(e) => setConfig({ ...config, active_crb_provider: e.target.value })}
              className={inputClass}
            >
              {CRB_PROVIDER_OPTIONS.map((code) => (
                <option key={code} value={code}>
                  {code === "" ? t("providerMock") : t(`crbProvider_${code}`)}
                </option>
              ))}
            </select>
          </label>
        </div>
      </div>

      {saveState === "error" && <p className="mb-4 text-sm text-red-600">{t("error")}</p>}

      <button
        type="submit"
        disabled={saveState === "saving"}
        className="inline-flex items-center gap-2 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
      >
        <Save size={16} />
        {saveState === "saved" ? t("saved") : t("save")}
      </button>
    </form>
  );
}

function LoanEligibilitySection() {
  const t = useTranslations("Settings");
  const [products, setProducts] = useState<LoanProductOption[]>([]);
  const [productId, setProductId] = useState("");
  const [policy, setPolicy] = useState<LoanEligibilityPolicy | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");

  useEffect(() => {
    apiFetch<{ results: LoanProductOption[] }>("/api/loans/products/")
      .then((data) => {
        setProducts(data.results);
        if (data.results.length > 0) setProductId(data.results[0].id);
        else setState("ready");
      })
      .catch(() => setState("forbidden"));
  }, []);

  useEffect(() => {
    if (!productId) return;
    apiFetch<LoanEligibilityPolicy>(`/api/rules-engine/loan-products/${productId}/eligibility-policy/`)
      .then((data) => {
        setPolicy(data);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 404) {
          setPolicy(DEFAULT_POLICY);
          setState("ready");
        } else if (err instanceof ApiError && err.status === 403) {
          setState("forbidden");
        } else {
          setState("forbidden");
        }
      });
  }, [productId]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!policy) return;
    setSaveState("saving");
    try {
      const updated = await apiFetch<LoanEligibilityPolicy>(
        `/api/rules-engine/loan-products/${productId}/eligibility-policy/`,
        { method: "PUT", body: JSON.stringify(policy) },
      );
      setPolicy(updated);
      setSaveState("saved");
      setTimeout(() => setSaveState("idle"), 2000);
    } catch {
      setSaveState("error");
    }
  }

  if (state === "loading") {
    return (
      <div className="mb-6 flex justify-center rounded-2xl bg-white py-12 shadow-sm ring-1 ring-primary-100/80">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "forbidden") {
    return (
      <div className="mb-6 rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  if (products.length === 0) {
    return (
      <div className="mb-6 rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-primary-500">{t("noLoanProducts")}</p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSave}>
      <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <h2 className="mb-1 text-sm font-semibold text-primary-900">{t("loanEligibility")}</h2>
        <p className="mb-4 text-sm text-primary-500">{t("loanEligibilityHelp")}</p>

        <label className="mb-4 block">
          <span className="mb-1 block text-sm font-medium text-primary-800">{t("selectProduct")}</span>
          <select value={productId} onChange={(e) => setProductId(e.target.value)} className={inputClass}>
            {products.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </label>

        {policy && (
          <>
            <label className="mb-4 flex items-center gap-2.5 rounded-lg border border-primary-100 px-4 py-3 text-sm text-primary-800">
              <input
                type="checkbox"
                checked={policy.is_active}
                onChange={(e) => setPolicy({ ...policy, is_active: e.target.checked })}
                className="h-4 w-4 rounded border-primary-300 text-primary-600 focus:ring-primary-500"
              />
              {t("policyIsActive")}
            </label>

            <div className="mb-4 grid grid-cols-2 gap-3">
              <label className="flex items-center gap-2.5 rounded-lg border border-primary-100 px-4 py-3 text-sm text-primary-800">
                <input
                  type="checkbox"
                  checked={policy.require_kyc_verified}
                  onChange={(e) => setPolicy({ ...policy, require_kyc_verified: e.target.checked })}
                  className="h-4 w-4 rounded border-primary-300 text-primary-600 focus:ring-primary-500"
                />
                {t("requireKycVerified")}
              </label>
              <label className="flex items-center gap-2.5 rounded-lg border border-primary-100 px-4 py-3 text-sm text-primary-800">
                <input
                  type="checkbox"
                  checked={policy.require_no_active_arrears}
                  onChange={(e) => setPolicy({ ...policy, require_no_active_arrears: e.target.checked })}
                  className="h-4 w-4 rounded border-primary-300 text-primary-600 focus:ring-primary-500"
                />
                {t("requireNoActiveArrears")}
              </label>
            </div>

            <div className="mb-4 grid grid-cols-3 gap-3">
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("maxActiveLoans")}</span>
                <input
                  type="number"
                  min={0}
                  className={inputClass}
                  value={policy.max_active_loans ?? ""}
                  onChange={(e) =>
                    setPolicy({ ...policy, max_active_loans: e.target.value ? Number(e.target.value) : null })
                  }
                />
              </label>
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("minMembershipMonths")}</span>
                <input
                  type="number"
                  min={0}
                  className={inputClass}
                  value={policy.min_membership_months}
                  onChange={(e) => setPolicy({ ...policy, min_membership_months: Number(e.target.value) || 0 })}
                />
              </label>
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">
                  {t("minGuarantorCoverageRatio")}
                </span>
                <input
                  type="number"
                  min={0}
                  step="0.01"
                  className={inputClass}
                  value={policy.min_guarantor_coverage_ratio ?? ""}
                  onChange={(e) =>
                    setPolicy({ ...policy, min_guarantor_coverage_ratio: e.target.value || null })
                  }
                />
              </label>
            </div>

            <label className="mb-4 flex items-center gap-2.5 rounded-lg border border-primary-100 px-4 py-3 text-sm text-primary-800">
              <input
                type="checkbox"
                checked={policy.require_crb_check}
                onChange={(e) => setPolicy({ ...policy, require_crb_check: e.target.checked })}
                className="h-4 w-4 rounded border-primary-300 text-primary-600 focus:ring-primary-500"
              />
              {t("requireCrbCheck")}
            </label>

            <div className="grid grid-cols-2 gap-3">
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("crbDenyBelowScore")}</span>
                <input
                  type="number"
                  min={0}
                  className={inputClass}
                  value={policy.crb_deny_below_score ?? ""}
                  onChange={(e) =>
                    setPolicy({ ...policy, crb_deny_below_score: e.target.value ? Number(e.target.value) : null })
                  }
                />
              </label>
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("crbReferBelowScore")}</span>
                <input
                  type="number"
                  min={0}
                  className={inputClass}
                  value={policy.crb_refer_below_score ?? ""}
                  onChange={(e) =>
                    setPolicy({ ...policy, crb_refer_below_score: e.target.value ? Number(e.target.value) : null })
                  }
                />
              </label>
            </div>
          </>
        )}
      </div>

      {saveState === "error" && <p className="mb-4 text-sm text-red-600">{t("error")}</p>}

      <button
        type="submit"
        disabled={saveState === "saving" || !policy}
        className="inline-flex items-center gap-2 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
      >
        <Save size={16} />
        {saveState === "saved" ? t("saved") : t("save")}
      </button>
    </form>
  );
}

type StaffRole = { id: string; name: string; description: string };

type StaffMember = {
  id: string;
  user_id: string;
  first_name: string;
  last_name: string;
  phone_number: string;
  email: string | null;
  role: string;
  role_name: string;
  job_title: string;
  is_active: boolean;
  assigned_at: string;
};

type StaffInvite = {
  id: string;
  token: string;
  phone_number: string;
  email: string | null;
  first_name: string;
  last_name: string;
  job_title: string;
  role: string;
  role_name: string;
  status: "pending" | "accepted" | "revoked" | "expired";
  created_at: string;
  expires_at: string;
  invite_path: string;
};

function StaffSection() {
  const t = useTranslations("Staff");
  const locale = useLocale();
  const [roles, setRoles] = useState<StaffRole[]>([]);
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [invites, setInvites] = useState<StaffInvite[]>([]);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");

  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [phoneNumber, setPhoneNumber] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [roleId, setRoleId] = useState("");
  const [inviting, setInviting] = useState(false);
  const [inviteError, setInviteError] = useState("");
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [rowError, setRowError] = useState<Record<string, string>>({});

  function load() {
    Promise.all([
      apiFetch<{ results: StaffRole[] }>("/api/tenant/roles/"),
      apiFetch<{ results: StaffMember[] }>("/api/tenant/staff/"),
      apiFetch<{ results: StaffInvite[] }>("/api/tenant/staff/invites/"),
    ])
      .then(([rolesData, staffData, invitesData]) => {
        setRoles(rolesData.results);
        setStaff(staffData.results);
        setInvites(invitesData.results);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 403) setState("forbidden");
        else setState("forbidden");
      });
  }

  useEffect(() => {
    load();
  }, []);

  async function handleInvite(e: React.FormEvent) {
    e.preventDefault();
    setInviting(true);
    setInviteError("");
    try {
      await apiFetch("/api/tenant/staff/invites/", {
        method: "POST",
        body: JSON.stringify({
          first_name: firstName,
          last_name: lastName,
          phone_number: phoneNumber,
          job_title: jobTitle,
          role: roleId,
        }),
      });
      setFirstName("");
      setLastName("");
      setPhoneNumber("");
      setJobTitle("");
      setRoleId("");
      load();
    } catch {
      setInviteError(t("inviteError"));
    } finally {
      setInviting(false);
    }
  }

  async function handleRoleChange(member: StaffMember, newRoleId: string) {
    setRowError((s) => ({ ...s, [member.id]: "" }));
    try {
      await apiFetch(`/api/tenant/staff/${member.id}/`, {
        method: "PATCH",
        body: JSON.stringify({ role: newRoleId }),
      });
      load();
    } catch (err) {
      setRowError((s) => ({ ...s, [member.id]: errorDetail(err, t("updateError")) }));
    }
  }

  async function handleToggleActive(member: StaffMember) {
    setRowError((s) => ({ ...s, [member.id]: "" }));
    try {
      await apiFetch(`/api/tenant/staff/${member.id}/`, {
        method: "PATCH",
        body: JSON.stringify({ is_active: !member.is_active }),
      });
      load();
    } catch (err) {
      setRowError((s) => ({ ...s, [member.id]: errorDetail(err, t("updateError")) }));
    }
  }

  async function handleRevoke(invite: StaffInvite) {
    await apiFetch(`/api/tenant/staff/invites/${invite.id}/revoke/`, { method: "POST" });
    load();
  }

  function inviteUrl(invite: StaffInvite) {
    return `${window.location.origin}/${locale}${invite.invite_path}`;
  }

  async function copyLink(invite: StaffInvite) {
    const copied = await copyToClipboard(inviteUrl(invite));
    if (copied) {
      setCopiedId(invite.id);
      setTimeout(() => setCopiedId(null), 2000);
    }
  }

  if (state === "loading") {
    return (
      <div className="mb-6 flex justify-center rounded-2xl bg-white py-12 shadow-sm ring-1 ring-primary-100/80">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "forbidden") {
    return (
      <div className="mb-6 rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  const pendingInvites = invites.filter((i) => i.status === "pending");

  return (
    <div>
      <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <h2 className="mb-4 text-sm font-semibold text-primary-900">{t("roster")}</h2>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] text-left text-sm">
            <thead>
              <tr className="border-b border-primary-100 text-xs font-medium uppercase tracking-wide text-primary-500">
                <th className="py-2 pr-3">{t("name")}</th>
                <th className="py-2 pr-3">{t("phoneNumber")}</th>
                <th className="py-2 pr-3">{t("jobTitle")}</th>
                <th className="py-2 pr-3">{t("role")}</th>
                <th className="py-2 pr-3">{t("status")}</th>
                <th className="py-2 pr-3" />
              </tr>
            </thead>
            <tbody>
              {staff.map((member) => (
                <tr key={member.id} className="border-b border-primary-50 last:border-0">
                  <td className="py-2.5 pr-3 font-medium text-primary-900">
                    {member.first_name} {member.last_name}
                  </td>
                  <td className="py-2.5 pr-3 font-mono text-primary-700">{member.phone_number}</td>
                  <td className="py-2.5 pr-3 text-primary-600">{member.job_title || "-"}</td>
                  <td className="py-2.5 pr-3">
                    <select
                      value={member.role}
                      onChange={(e) => handleRoleChange(member, e.target.value)}
                      className="rounded-lg border border-primary-200 bg-white px-2 py-1.5 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                    >
                      {roles.map((r) => (
                        <option key={r.id} value={r.id}>
                          {r.name}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td className="py-2.5 pr-3">
                    <span
                      className={
                        "inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-medium " +
                        (member.is_active
                          ? "bg-primary-100 text-primary-800"
                          : "bg-red-50 text-red-700")
                      }
                    >
                      {member.is_active ? t("active") : t("inactive")}
                    </span>
                  </td>
                  <td className="py-2.5 pr-3 text-right">
                    <button
                      onClick={() => handleToggleActive(member)}
                      className="text-xs font-medium text-primary-600 hover:underline"
                    >
                      {member.is_active ? t("deactivate") : t("reactivate")}
                    </button>
                    {rowError[member.id] && (
                      <p className="mt-1 text-xs text-red-600">{rowError[member.id]}</p>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <form
        onSubmit={handleInvite}
        className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80"
      >
        <div className="mb-4 flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
            <UserPlus size={16} strokeWidth={2} />
          </div>
          <h2 className="text-sm font-semibold text-primary-900">{t("inviteStaff")}</h2>
        </div>
        <p className="mb-4 text-sm text-primary-500">{t("inviteStaffHelp")}</p>

        <div className="mb-4 grid grid-cols-2 gap-3">
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("firstName")}</span>
            <input
              required
              className={inputClass}
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("lastName")}</span>
            <input
              required
              className={inputClass}
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
            />
          </label>
        </div>

        <div className="mb-4 grid grid-cols-2 gap-3">
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("phoneNumber")}</span>
            <input
              required
              type="tel"
              placeholder="+254700000000"
              className={inputClass}
              value={phoneNumber}
              onChange={(e) => setPhoneNumber(e.target.value)}
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-sm font-medium text-primary-800">{t("jobTitle")}</span>
            <input
              className={inputClass}
              value={jobTitle}
              onChange={(e) => setJobTitle(e.target.value)}
            />
          </label>
        </div>

        <label className="mb-4 block">
          <span className="mb-1 block text-sm font-medium text-primary-800">{t("role")}</span>
          <select
            required
            value={roleId}
            onChange={(e) => setRoleId(e.target.value)}
            className={inputClass}
          >
            <option value="" disabled>
              {t("selectRole")}
            </option>
            {roles.map((r) => (
              <option key={r.id} value={r.id}>
                {r.name}
              </option>
            ))}
          </select>
        </label>

        {inviteError && <p className="mb-3 text-sm text-red-600">{inviteError}</p>}

        <button
          type="submit"
          disabled={inviting}
          className="inline-flex items-center gap-2 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
        >
          <UserPlus size={16} />
          {t("sendInvite")}
        </button>
      </form>

      <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <h2 className="mb-1 text-sm font-semibold text-primary-900">{t("pendingInvites")}</h2>
        <p className="mb-4 text-sm text-primary-500">{t("pendingInvitesHelp")}</p>

        {pendingInvites.length === 0 && (
          <p className="text-sm text-primary-500">{t("noPendingInvites")}</p>
        )}

        <ul className="space-y-3">
          {pendingInvites.map((invite) => (
            <li
              key={invite.id}
              className="flex flex-col gap-2 rounded-lg border border-primary-100 p-4 sm:flex-row sm:items-center sm:justify-between"
            >
              <div>
                <p className="text-sm font-medium text-primary-900">
                  {invite.first_name} {invite.last_name}{" "}
                  <span className="font-normal text-primary-500">({invite.role_name})</span>
                </p>
                <p className="font-mono text-xs text-primary-500">{invite.phone_number}</p>
              </div>
              <div className="flex items-center gap-3">
                <button
                  type="button"
                  onClick={() => copyLink(invite)}
                  className="inline-flex items-center gap-1.5 text-xs font-medium text-primary-600 hover:underline"
                >
                  {copiedId === invite.id ? <Check size={13} /> : <Copy size={13} />}
                  {copiedId === invite.id ? t("copied") : t("copyLink")}
                </button>
                <button
                  type="button"
                  onClick={() => handleRevoke(invite)}
                  className="inline-flex items-center gap-1.5 text-xs font-medium text-red-600 hover:underline"
                >
                  <XCircle size={13} />
                  {t("revoke")}
                </button>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function errorDetail(err: unknown, fallback: string) {
  if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
    const detail = (err.body as { detail?: string }).detail;
    if (detail) return detail;
  }
  return fallback;
}

