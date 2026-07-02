"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Building2, Hash, ImagePlus, Save } from "lucide-react";
import { apiFetch, ApiError } from "@/lib/api";
import { useTenantProfile } from "@/lib/TenantProfileContext";

type TenantConfig = {
  default_language: string;
  allowed_id_types: string[];
  member_number_prefix: string;
  member_number_suffix: string;
  member_number_padding: number;
  member_number_next_sequence: number;
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
] as const;

type TabKey = (typeof TABS)[number]["key"];

export default function SettingsPage() {
  const t = useTranslations("Settings");
  const [tab, setTab] = useState<TabKey>("sacco");

  return (
    <div className="mx-auto max-w-2xl">
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
