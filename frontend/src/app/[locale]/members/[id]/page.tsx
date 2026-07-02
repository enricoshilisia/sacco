"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { Link, useRouter } from "@/i18n/navigation";
import { apiFetch, ApiError, getAccessToken } from "@/lib/api";
import LanguageSwitcher from "@/components/LanguageSwitcher";

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

  return (
    <div className="flex min-h-full flex-col bg-primary-50">
      <header className="flex items-center justify-between px-4 py-4 sm:px-6">
        <Link href="/members" className="text-sm text-primary-600 hover:underline">
          &larr; {t("title")}
        </Link>
        <LanguageSwitcher />
      </header>

      <main className="flex-1 px-4 py-6 sm:px-6">
        {state === "loading" && <p className="text-sm text-primary-600">{t("loading")}</p>}
        {state === "error" && <p className="text-sm text-red-600">{t("forbidden")}</p>}

        {state === "ready" && member && (
          <div className="mx-auto max-w-2xl">
            <div className="mb-4 flex items-center justify-between">
              <div>
                <h1 className="text-lg font-semibold text-primary-900">
                  {member.first_name} {member.other_names} {member.last_name}
                </h1>
                <p className="font-mono text-sm text-primary-500">{member.member_number}</p>
              </div>
              <span
                className={
                  "rounded-full px-3 py-1 text-xs font-medium " +
                  (member.is_kyc_verified
                    ? "bg-primary-100 text-primary-800"
                    : "bg-amber-100 text-amber-800")
                }
              >
                {member.is_kyc_verified ? t("kycVerified") : t("kycPending")}
              </span>
            </div>

            <div className="mb-4 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100">
              <dl className="space-y-3 text-sm">
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
                  className="mt-4 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white hover:bg-primary-700 disabled:opacity-60"
                >
                  {t("verifyKyc")}
                </button>
              )}
            </div>

            {member.relations.length > 0 && (
              <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100">
                <h2 className="mb-3 text-sm font-semibold text-primary-800">{t("relationsSection")}</h2>
                <ul className="space-y-3">
                  {member.relations.map((r) => (
                    <li key={r.id} className="rounded-lg border border-primary-100 p-3 text-sm">
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
        )}
      </main>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-primary-500">{label}</dt>
      <dd className="text-right font-medium text-primary-900">{value}</dd>
    </div>
  );
}
