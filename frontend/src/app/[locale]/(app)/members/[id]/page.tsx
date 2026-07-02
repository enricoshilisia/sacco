"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { ArrowLeft, CheckCircle2, Clock, Users } from "lucide-react";
import { Link, useRouter } from "@/i18n/navigation";
import { apiFetch, ApiError, getAccessToken } from "@/lib/api";

type MemberDetail = {
  id: string;
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
  is_kyc_verified: boolean;
  relations: {
    id: string;
    kind: string;
    full_name: string;
    relationship: string;
    phone_number: string;
    benefit_percentage: string | null;
  }[];
};

export default function MemberDetailPage() {
  const t = useTranslations("Members");
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const [member, setMember] = useState<MemberDetail | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "error">("loading");
  const [verifying, setVerifying] = useState(false);

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace("/login");
      return;
    }
    apiFetch<MemberDetail>(`/api/members/${params.id}/`)
      .then((data) => {
        setMember(data);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 401) router.replace("/login");
        else setState("error");
      });
  }, [params.id, router]);

  async function handleVerifyKyc() {
    if (!member) return;
    setVerifying(true);
    try {
      const updated = await apiFetch<MemberDetail>(`/api/members/${member.id}/verify-kyc/`, {
        method: "POST",
      });
      setMember(updated);
    } finally {
      setVerifying(false);
    }
  }

  const relationKindLabel: Record<string, string> = {
    NEXT_OF_KIN: t("kindNextOfKin"),
    NOMINEE: t("kindNominee"),
    BENEFICIARY: t("kindBeneficiary"),
  };
  const categoryLabel: Record<string, string> = {
    ORDINARY: t("categoryOrdinary"),
    ASSOCIATE: t("categoryAssociate"),
    JUNIOR: t("categoryJunior"),
    CORPORATE: t("categoryCorporate"),
  };
  const idTypeLabel: Record<string, string> = {
    NATIONAL_ID: t("idNational"),
    HUDUMA: t("idHuduma"),
    NIDA: t("idNida"),
    PASSPORT: t("idPassport"),
  };

  if (state === "loading") {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "error" || !member) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  const fullName = `${member.first_name} ${member.other_names} ${member.last_name}`.replace(/\s+/g, " ").trim();
  const initials = `${member.first_name[0] ?? ""}${member.last_name[0] ?? ""}`.toUpperCase();

  return (
    <div className="mx-auto max-w-2xl">
      <Link
        href="/members"
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-primary-600 hover:text-primary-800"
      >
        <ArrowLeft size={16} />
        {t("title")}
      </Link>

      <div className="mb-5 flex items-center gap-4">
        <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-primary-100 text-lg font-semibold text-primary-700">
          {initials}
        </div>
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-xl font-semibold text-primary-900">{fullName}</h1>
          <p className="font-mono text-sm text-primary-500">{member.member_number}</p>
        </div>
        <span
          className={
            "inline-flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium " +
            (member.is_kyc_verified
              ? "bg-primary-100 text-primary-800"
              : "bg-amber-100 text-amber-800")
          }
        >
          {member.is_kyc_verified ? <CheckCircle2 size={13} /> : <Clock size={13} />}
          {member.is_kyc_verified ? t("kycVerified") : t("kycPending")}
        </span>
      </div>

      <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <dl className="divide-y divide-primary-50">
          <Row label={t("category")} value={categoryLabel[member.category] ?? member.category} />
          <Row label={t("idType")} value={idTypeLabel[member.id_type] ?? member.id_type} />
          <Row label={t("idNumber")} value={member.id_number} />
          <Row label={t("phoneNumber")} value={member.phone_number} />
          {member.email && <Row label={t("email")} value={member.email} />}
          {member.physical_address && (
            <Row label={t("physicalAddress")} value={member.physical_address} />
          )}
        </dl>

        {!member.is_kyc_verified && (
          <button
            onClick={handleVerifyKyc}
            disabled={verifying}
            className="mt-5 inline-flex items-center gap-2 rounded-full bg-primary-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            <CheckCircle2 size={16} />
            {t("verifyKyc")}
          </button>
        )}
      </div>

      {member.relations.length > 0 && (
        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <Users size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("relationsSection")}</h2>
          </div>
          <ul className="space-y-3">
            {member.relations.map((r) => (
              <li key={r.id} className="rounded-lg border border-primary-100 p-4 text-sm">
                <p className="font-medium text-primary-900">
                  {r.full_name}{" "}
                  <span className="font-normal text-primary-500">
                    ({relationKindLabel[r.kind] ?? r.kind})
                  </span>
                </p>
                <p className="text-primary-600">{r.relationship}</p>
                {r.phone_number && <p className="text-primary-600">{r.phone_number}</p>}
                {r.benefit_percentage && (
                  <p className="text-primary-600">{r.benefit_percentage}%</p>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4 py-2.5 first:pt-0 last:pb-0">
      <dt className="text-sm text-primary-500">{label}</dt>
      <dd className="text-right text-sm font-medium text-primary-900">{value}</dd>
    </div>
  );
}
