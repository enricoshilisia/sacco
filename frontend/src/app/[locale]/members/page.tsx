"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Link, useRouter } from "@/i18n/navigation";
import { apiFetch, ApiError, getAccessToken } from "@/lib/api";
import LanguageSwitcher from "@/components/LanguageSwitcher";

type MemberListItem = {
  id: string;
  member_number: string;
  full_name: string;
  category: string;
  status: string;
  phone_number: string;
  is_kyc_verified: boolean;
};

type PageState = "loading" | "ready" | "forbidden" | "expired";

export default function MembersListPage() {
  const t = useTranslations("Members");
  const tNav = useTranslations("Nav");
  const router = useRouter();
  const [members, setMembers] = useState<MemberListItem[]>([]);
  const [state, setState] = useState<PageState>("loading");

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace("/login");
      return;
    }
    apiFetch<{ results: MemberListItem[] }>("/api/members/")
      .then((data) => {
        setMembers(data.results);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 401) setState("expired");
        else if (err instanceof ApiError && err.status === 403) setState("forbidden");
        else setState("forbidden");
      });
  }, [router]);

  const categoryLabel: Record<string, string> = {
    ORDINARY: t("categoryOrdinary"),
    ASSOCIATE: t("categoryAssociate"),
    JUNIOR: t("categoryJunior"),
    CORPORATE: t("categoryCorporate"),
  };

  return (
    <div className="flex min-h-full flex-col bg-primary-50">
      <header className="flex items-center justify-between px-4 py-4 sm:px-6">
        <div className="flex items-center gap-3">
          <Link href="/dashboard" className="text-sm text-primary-600 hover:underline">
            &larr; {t("backToDashboard")}
          </Link>
        </div>
        <div className="flex items-center gap-3">
          <LanguageSwitcher />
        </div>
      </header>

      <main className="flex-1 px-4 py-6 sm:px-6">
        <div className="mb-4 flex items-center justify-between">
          <h1 className="text-lg font-semibold text-primary-900">{t("title")}</h1>
          {state === "ready" && (
            <Link
              href="/members/new"
              className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-primary-700"
            >
              {t("addMember")}
            </Link>
          )}
        </div>

        {state === "loading" && <p className="text-sm text-primary-600">{t("loading")}</p>}
        {state === "expired" && <p className="text-sm text-primary-600">{tNav("logout")}...</p>}
        {state === "forbidden" && <p className="text-sm text-red-600">{t("forbidden")}</p>}

        {state === "ready" && members.length === 0 && (
          <p className="text-sm text-primary-600">{t("empty")}</p>
        )}

        {state === "ready" && members.length > 0 && (
          <div className="overflow-x-auto rounded-2xl bg-white shadow-sm ring-1 ring-primary-100">
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead>
                <tr className="border-b border-primary-100 text-xs uppercase tracking-wide text-primary-500">
                  <th className="px-4 py-3">{t("memberNumber")}</th>
                  <th className="px-4 py-3">{t("name")}</th>
                  <th className="px-4 py-3">{t("category")}</th>
                  <th className="px-4 py-3">{t("phoneNumber")}</th>
                  <th className="px-4 py-3">{t("kyc")}</th>
                </tr>
              </thead>
              <tbody>
                {members.map((m) => (
                  <tr key={m.id} className="border-b border-primary-50 last:border-0">
                    <td className="px-4 py-3 font-mono text-primary-800">{m.member_number}</td>
                    <td className="px-4 py-3 text-primary-900">{m.full_name}</td>
                    <td className="px-4 py-3 text-primary-700">
                      {categoryLabel[m.category] ?? m.category}
                    </td>
                    <td className="px-4 py-3 text-primary-700">{m.phone_number}</td>
                    <td className="px-4 py-3">
                      <span
                        className={
                          "rounded-full px-2.5 py-1 text-xs font-medium " +
                          (m.is_kyc_verified
                            ? "bg-primary-100 text-primary-800"
                            : "bg-amber-100 text-amber-800")
                        }
                      >
                        {m.is_kyc_verified ? t("kycVerified") : t("kycPending")}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </div>
  );
}
