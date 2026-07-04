"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { CheckCircle2, Clock, IdCard, Save, User } from "lucide-react";
import { apiFetch, ApiError } from "@/lib/api";
import { useTenantProfile } from "@/lib/TenantProfileContext";

type MyMember = {
  member_number: string;
  category: string;
  status: string;
  first_name: string;
  last_name: string;
  other_names: string;
  id_type: string;
  id_number: string;
  phone_number: string;
  email: string;
  physical_address: string;
  is_kyc_verified: boolean;
};

const inputClass =
  "w-full rounded-lg border border-primary-200 bg-white px-4 py-3 text-base text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500";

function errorDetail(err: unknown, fallback: string) {
  if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
    const detail = (err.body as { detail?: string }).detail;
    if (detail) return detail;
  }
  return fallback;
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4 py-2.5 first:pt-0 last:pb-0">
      <dt className="text-sm text-primary-500">{label}</dt>
      <dd className="text-right text-sm font-medium text-primary-900">{value}</dd>
    </div>
  );
}

export default function ProfilePage() {
  const t = useTranslations("Profile");
  const tm = useTranslations("Members");
  const { myMemberId } = useTenantProfile();

  const [member, setMember] = useState<MyMember | null | undefined>(undefined);
  const [phoneNumber, setPhoneNumber] = useState("");
  const [email, setEmail] = useState("");
  const [physicalAddress, setPhysicalAddress] = useState("");
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [error, setError] = useState("");

  useEffect(() => {
    if (myMemberId) {
      apiFetch<MyMember>("/api/members/me/")
        .then((data) => {
          setMember(data);
          setPhoneNumber(data.phone_number);
          setEmail(data.email);
          setPhysicalAddress(data.physical_address);
        })
        .catch(() => setMember(null));
    }
  }, [myMemberId]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaveState("saving");
    setError("");
    try {
      const updated = await apiFetch<MyMember>("/api/members/me/", {
        method: "PATCH",
        body: JSON.stringify({
          phone_number: phoneNumber,
          email,
          physical_address: physicalAddress,
        }),
      });
      setMember(updated);
      setSaveState("saved");
      setTimeout(() => setSaveState("idle"), 2000);
    } catch (err) {
      setError(errorDetail(err, t("error")));
      setSaveState("error");
    }
  }

  const categoryLabel: Record<string, string> = {
    ORDINARY: tm("categoryOrdinary"),
    ASSOCIATE: tm("categoryAssociate"),
    JUNIOR: tm("categoryJunior"),
    CORPORATE: tm("categoryCorporate"),
  };
  const idTypeLabel: Record<string, string> = {
    NATIONAL_ID: tm("idNational"),
    HUDUMA: tm("idHuduma"),
    NIDA: tm("idNida"),
    PASSPORT: tm("idPassport"),
  };

  if (myMemberId === undefined || member === undefined) {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (!myMemberId || member === null) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  const fullName = [member.first_name, member.other_names, member.last_name].filter(Boolean).join(" ");

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("title")}</h1>

      <section className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <div className="mb-1 flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <IdCard size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("memberDetails")}</h2>
          </div>
          <span
            className={
              "inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium " +
              (member.is_kyc_verified ? "bg-primary-100 text-primary-800" : "bg-amber-100 text-amber-800")
            }
          >
            {member.is_kyc_verified ? <CheckCircle2 size={12} /> : <Clock size={12} />}
            {member.is_kyc_verified ? tm("kycVerified") : tm("kycPending")}
          </span>
        </div>
        <p className="mb-4 text-xs text-primary-500">{t("memberDetailsHelp")}</p>

        <dl className="divide-y divide-primary-50">
          <Row label={tm("name")} value={fullName} />
          <Row label={tm("memberNumber")} value={member.member_number} />
          <Row label={tm("category")} value={categoryLabel[member.category] ?? member.category} />
          <Row label={tm("idType")} value={idTypeLabel[member.id_type] ?? member.id_type} />
          <Row label={tm("idNumber")} value={member.id_number} />
        </dl>
      </section>

      <form
        onSubmit={handleSave}
        className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80"
      >
        <div className="mb-1 flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
            <User size={16} strokeWidth={2} />
          </div>
          <h2 className="text-sm font-semibold text-primary-900">{t("contactDetails")}</h2>
        </div>
        <p className="mb-4 text-xs text-primary-500">{t("contactDetailsHelp")}</p>

        <label className="mb-4 block">
          <span className="mb-1 block text-sm font-medium text-primary-800">{tm("phoneNumber")}</span>
          <input
            type="tel"
            className={inputClass}
            value={phoneNumber}
            onChange={(e) => setPhoneNumber(e.target.value)}
          />
        </label>

        <label className="mb-4 block">
          <span className="mb-1 block text-sm font-medium text-primary-800">{tm("email")}</span>
          <input
            type="email"
            className={inputClass}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>

        <label className="mb-2 block">
          <span className="mb-1 block text-sm font-medium text-primary-800">{tm("physicalAddress")}</span>
          <input
            type="text"
            className={inputClass}
            value={physicalAddress}
            onChange={(e) => setPhysicalAddress(e.target.value)}
          />
        </label>

        {saveState === "error" && <p className="mb-2 mt-3 text-sm text-red-600">{error}</p>}

        <button
          type="submit"
          disabled={saveState === "saving"}
          className="mt-4 inline-flex items-center gap-2 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
        >
          <Save size={16} />
          {saveState === "saved" ? t("saved") : t("save")}
        </button>
      </form>
    </div>
  );
}
