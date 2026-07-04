"use client";

import { useRef, useState, useEffect } from "react";
import { useTranslations } from "next-intl";
import { Camera, CheckCircle2, Clock, IdCard, KeyRound, Mail, Save, User } from "lucide-react";
import { apiFetch, ApiError } from "@/lib/api";
import { useTenantProfile } from "@/lib/TenantProfileContext";

type MyMember = {
  member_number: string;
  category: string;
  status: string;
  first_name: string;
  last_name: string;
  other_names: string;
  date_of_birth: string | null;
  gender: string;
  id_type: string;
  id_number: string;
  phone_number: string;
  email: string;
  physical_address: string;
  photo: string | null;
  is_kyc_verified: boolean;
  date_joined: string;
};

const inputClass =
  "w-full rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500";
const disabledInputClass =
  "w-full rounded-lg border border-primary-100 bg-primary-50/60 px-3 py-2 text-sm text-primary-700";

function errorDetail(err: unknown, fallback: string) {
  if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
    const detail = (err.body as { detail?: string }).detail;
    if (detail) return detail;
  }
  return fallback;
}

function CardHeader({ icon: Icon, title }: { icon: typeof User; title: string }) {
  return (
    <div className="mb-4 flex items-center gap-2.5">
      <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
        <Icon size={15} strokeWidth={2} />
      </div>
      <h2 className="text-sm font-semibold text-primary-900">{title}</h2>
    </div>
  );
}

const TABS = ["personal", "security"] as const;
type TabKey = (typeof TABS)[number];

export default function ProfilePage() {
  const t = useTranslations("Profile");
  const tm = useTranslations("Members");
  const { myMemberId } = useTenantProfile();

  const [tab, setTab] = useState<TabKey>("personal");
  const [member, setMember] = useState<MyMember | undefined>(undefined);
  const [phoneNumber, setPhoneNumber] = useState("");
  const [email, setEmail] = useState("");
  const [physicalAddress, setPhysicalAddress] = useState("");
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [error, setError] = useState("");
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (myMemberId) {
      apiFetch<MyMember>("/api/members/me/").then((data) => {
        setMember(data);
        setPhoneNumber(data.phone_number);
        setEmail(data.email);
        setPhysicalAddress(data.physical_address);
      });
    }
  }, [myMemberId]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaveState("saving");
    setError("");
    try {
      const updated = await apiFetch<MyMember>("/api/members/me/", {
        method: "PATCH",
        body: JSON.stringify({ phone_number: phoneNumber, email, physical_address: physicalAddress }),
      });
      setMember(updated);
      setSaveState("saved");
      setTimeout(() => setSaveState("idle"), 2000);
    } catch (err) {
      setError(errorDetail(err, t("error")));
      setSaveState("error");
    }
  }

  async function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingPhoto(true);
    try {
      const form = new FormData();
      form.append("photo", file);
      const updated = await apiFetch<MyMember>("/api/members/me/photo/", { method: "POST", body: form });
      setMember(updated);
    } finally {
      setUploadingPhoto(false);
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
  const genderLabel: Record<string, string> = {
    FEMALE: tm("genderFemale"),
    MALE: tm("genderMale"),
    OTHER: tm("genderOther"),
  };

  const isMember = !!myMemberId;
  // While myMemberId is still resolving, or a confirmed member's own record
  // hasn't loaded yet, show a spinner rather than flashing a "Security only"
  // view that would otherwise render before we know which tabs apply.
  const stillLoading = myMemberId === undefined || (isMember && member === undefined);
  const effectiveTab: TabKey = isMember ? tab : "security";
  const fullName = member ? [member.first_name, member.other_names, member.last_name].filter(Boolean).join(" ") : "";
  const initials = member ? `${member.first_name[0] ?? ""}${member.last_name[0] ?? ""}`.toUpperCase() : "";

  return (
    <div className="mx-auto max-w-3xl">
      {stillLoading ? (
        <div className="flex justify-center py-16">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
        </div>
      ) : (
        <>
          {isMember && member && (
            <div className="mb-5 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-primary-100/80">
              <div className="h-20 bg-gradient-to-r from-primary-600 to-primary-800" />
              <div className="px-6 pb-5">
                <div className="-mt-10 mb-3 flex items-end gap-4">
                  <button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    disabled={uploadingPhoto}
                    className="group relative flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary-100 text-xl font-semibold text-primary-700 ring-4 ring-white"
                  >
                    {member.photo ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={member.photo} alt="" className="h-full w-full object-cover" />
                    ) : (
                      initials
                    )}
                    <span className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 transition-opacity group-hover:opacity-100">
                      <Camera size={18} className="text-white" />
                    </span>
                  </button>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={handlePhotoChange}
                  />
                  <div className="min-w-0 flex-1 pb-1">
                    <h1 className="truncate text-lg font-semibold text-primary-900">{fullName}</h1>
                    <p className="font-mono text-xs text-primary-500">{member.member_number}</p>
                  </div>
                </div>

                <div className="flex flex-wrap gap-2">
                  <span className="inline-flex items-center gap-1.5 rounded-full bg-primary-50 px-3 py-1 text-xs font-medium text-primary-700 ring-1 ring-primary-100">
                    {member.status === "ACTIVE" ? (
                      <CheckCircle2 size={12} className="text-primary-600" />
                    ) : (
                      <Clock size={12} className="text-amber-600" />
                    )}
                    {member.status}
                  </span>
                  <span className="inline-flex items-center gap-1.5 rounded-full bg-primary-50 px-3 py-1 text-xs font-medium text-primary-700 ring-1 ring-primary-100">
                    <IdCard size={12} />
                    {categoryLabel[member.category] ?? member.category}
                  </span>
                  <span
                    className={
                      "inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium ring-1 " +
                      (member.is_kyc_verified
                        ? "bg-primary-50 text-primary-700 ring-primary-100"
                        : "bg-amber-50 text-amber-800 ring-amber-100")
                    }
                  >
                    {member.is_kyc_verified ? tm("kycVerified") : tm("kycPending")}
                  </span>
                </div>
              </div>
            </div>
          )}

          <div className="mb-5 flex gap-1 border-b border-primary-100">
            {TABS.filter((key) => isMember || key === "security").map((key) => (
              <button
                key={key}
                type="button"
                onClick={() => setTab(key)}
                className={
                  "flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors " +
                  (effectiveTab === key
                    ? "border-primary-600 text-primary-700"
                    : "border-transparent text-primary-500 hover:text-primary-700")
                }
              >
                {key === "personal" ? t("tabPersonal") : t("tabSecurity")}
              </button>
            ))}
          </div>

          {effectiveTab === "personal" && isMember && member && (
            <div className="grid gap-5 sm:grid-cols-2">
              <section className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100/80">
                <CardHeader icon={User} title={t("basicInfo")} />
                <div className="space-y-3">
                  <label className="block">
                    <span className="mb-1 block text-xs font-medium text-primary-600">{tm("firstName")}</span>
                    <input disabled value={member.first_name} className={disabledInputClass} />
                  </label>
                  <label className="block">
                    <span className="mb-1 block text-xs font-medium text-primary-600">{tm("lastName")}</span>
                    <input disabled value={member.last_name} className={disabledInputClass} />
                  </label>
                  <label className="block">
                    <span className="mb-1 block text-xs font-medium text-primary-600">{tm("gender")}</span>
                    <input
                      disabled
                      value={genderLabel[member.gender] || t("notProvided")}
                      className={disabledInputClass}
                    />
                  </label>
                  <label className="block">
                    <span className="mb-1 block text-xs font-medium text-primary-600">{tm("idType")}</span>
                    <input disabled value={idTypeLabel[member.id_type] ?? member.id_type} className={disabledInputClass} />
                  </label>
                  <label className="block">
                    <span className="mb-1 block text-xs font-medium text-primary-600">{tm("idNumber")}</span>
                    <input disabled value={member.id_number} className={disabledInputClass} />
                  </label>
                </div>
                <p className="mt-3 text-xs text-primary-400">{t("basicInfoHelp")}</p>
              </section>

              <form onSubmit={handleSave} className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100/80">
                <CardHeader icon={Mail} title={t("contact")} />
                <div className="space-y-3">
                  <label className="block">
                    <span className="mb-1 block text-xs font-medium text-primary-600">{tm("phoneNumber")}</span>
                    <input
                      type="tel"
                      className={inputClass}
                      value={phoneNumber}
                      onChange={(e) => setPhoneNumber(e.target.value)}
                    />
                  </label>
                  <label className="block">
                    <span className="mb-1 block text-xs font-medium text-primary-600">{tm("email")}</span>
                    <input
                      type="email"
                      className={inputClass}
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                    />
                  </label>
                  <label className="block">
                    <span className="mb-1 block text-xs font-medium text-primary-600">{tm("physicalAddress")}</span>
                    <input
                      type="text"
                      className={inputClass}
                      value={physicalAddress}
                      onChange={(e) => setPhysicalAddress(e.target.value)}
                    />
                  </label>
                </div>

                {saveState === "error" && <p className="mt-2 text-xs text-red-600">{error}</p>}

                <button
                  type="submit"
                  disabled={saveState === "saving"}
                  className="mt-4 inline-flex items-center gap-2 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
                >
                  <Save size={15} />
                  {saveState === "saved" ? t("saved") : t("save")}
                </button>
              </form>
            </div>
          )}

          {effectiveTab === "security" && <ChangePasswordCard />}
        </>
      )}
    </div>
  );
}

function ChangePasswordCard() {
  const t = useTranslations("Profile");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [error, setError] = useState("");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    if (newPassword !== confirmPassword) {
      setError(t("passwordMismatch"));
      setSaveState("error");
      return;
    }
    setSaveState("saving");
    try {
      await apiFetch("/api/auth/me/change-password/", {
        method: "POST",
        body: JSON.stringify({ current_password: currentPassword, new_password: newPassword }),
      });
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      setSaveState("saved");
      setTimeout(() => setSaveState("idle"), 2000);
    } catch (err) {
      setError(errorDetail(err, t("error")));
      setSaveState("error");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="max-w-lg rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100/80">
      <CardHeader icon={KeyRound} title={t("changePassword")} />
      <p className="mb-3 -mt-2 text-xs text-primary-500">{t("changePasswordHelp")}</p>

      <div className="space-y-3">
        <label className="block">
          <span className="mb-1 block text-xs font-medium text-primary-600">{t("currentPassword")}</span>
          <input
            type="password"
            className={inputClass}
            value={currentPassword}
            onChange={(e) => setCurrentPassword(e.target.value)}
          />
        </label>
        <label className="block">
          <span className="mb-1 block text-xs font-medium text-primary-600">{t("newPassword")}</span>
          <input
            type="password"
            minLength={8}
            className={inputClass}
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
          />
        </label>
        <label className="block">
          <span className="mb-1 block text-xs font-medium text-primary-600">{t("confirmPassword")}</span>
          <input
            type="password"
            minLength={8}
            className={inputClass}
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
          />
        </label>
      </div>

      {saveState === "error" && <p className="mt-2 text-xs text-red-600">{error}</p>}

      <button
        type="submit"
        disabled={saveState === "saving" || !currentPassword || !newPassword}
        className="mt-4 inline-flex items-center gap-2 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
      >
        <KeyRound size={15} />
        {saveState === "saved" ? t("saved") : t("changePasswordSubmit")}
      </button>
    </form>
  );
}
