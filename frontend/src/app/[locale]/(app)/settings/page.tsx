"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Save, Settings as SettingsIcon } from "lucide-react";
import { apiFetch, ApiError } from "@/lib/api";

type TenantConfig = {
  default_language: string;
  allowed_id_types: string[];
  member_number_prefix: string;
  member_number_padding: number;
  member_number_next_sequence: number;
};

const ID_TYPES = ["NATIONAL_ID", "HUDUMA", "NIDA", "PASSPORT"] as const;

const inputClass =
  "w-full rounded-lg border border-primary-200 bg-white px-4 py-3 text-base text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500";

export default function SettingsPage() {
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
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "forbidden" || !config) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  const previewNumber = `${config.member_number_prefix}${String(config.member_number_next_sequence).padStart(config.member_number_padding, "0")}`;

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("title")}</h1>

      <form onSubmit={handleSave}>
        <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-5 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <SettingsIcon size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("memberNumbering")}</h2>
          </div>
          <p className="mb-4 text-sm text-primary-500">{t("memberNumberingHelp")}</p>

          <div className="mb-4 grid grid-cols-2 gap-3">
            <label className="block">
              <span className="mb-1 block text-sm font-medium text-primary-800">{t("prefix")}</span>
              <input
                className={inputClass}
                value={config.member_number_prefix}
                maxLength={20}
                onChange={(e) => setConfig({ ...config, member_number_prefix: e.target.value })}
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
    </div>
  );
}
