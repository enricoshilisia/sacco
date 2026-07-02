"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { UserPlus, Users } from "lucide-react";
import { Link, useRouter } from "@/i18n/navigation";
import { apiFetch, ApiError, getAccessToken } from "@/lib/api";

type MemberListItem = {
  id: string;
  member_number: string;
  full_name: string;
  category: string;
  status: string;
  phone_number: string;
  is_kyc_verified: boolean;
  photo: string | null;
};

type PageState = "loading" | "ready" | "forbidden" | "expired";

export default function MembersListPage() {
  const t = useTranslations("Members");
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
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-xl font-semibold text-primary-900">{t("title")}</h1>
        {state === "ready" && (
          <Link
            href="/members/new"
            className="inline-flex items-center gap-2 rounded-full bg-primary-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700"
          >
            <UserPlus size={16} />
            {t("addMember")}
          </Link>
        )}
      </div>

      {state === "loading" && (
        <div className="flex justify-center py-16">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
        </div>
      )}
      {state === "expired" && <p className="text-sm text-primary-600">...</p>}
      {state === "forbidden" && (
        <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
          <p className="text-sm text-red-600">{t("forbidden")}</p>
        </div>
      )}

      {state === "ready" && members.length === 0 && (
        <div className="flex flex-col items-center gap-3 rounded-2xl bg-white p-12 text-center shadow-sm ring-1 ring-primary-100/80">
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary-50 text-primary-400">
            <Users size={22} />
          </div>
          <p className="text-sm text-primary-600">{t("empty")}</p>
        </div>
      )}

      {state === "ready" && members.length > 0 && (
        <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-primary-100/80">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead>
                <tr className="border-b border-primary-100 bg-primary-50/50 text-xs font-medium uppercase tracking-wide text-primary-500">
                  <th className="w-10 px-5 py-3"></th>
                  <th className="px-5 py-3">{t("memberNumber")}</th>
                  <th className="px-5 py-3">{t("name")}</th>
                  <th className="px-5 py-3">{t("category")}</th>
                  <th className="px-5 py-3">{t("phoneNumber")}</th>
                  <th className="px-5 py-3">{t("kyc")}</th>
                </tr>
              </thead>
              <tbody>
                {members.map((m) => (
                  <tr
                    key={m.id}
                    onClick={() => router.push(`/members/${m.id}`)}
                    className="cursor-pointer border-b border-primary-50 transition-colors last:border-0 hover:bg-primary-50/40"
                  >
                    <td className="px-5 py-3.5">
                      <div className="flex h-8 w-8 items-center justify-center overflow-hidden rounded-full bg-primary-100 text-xs font-semibold text-primary-700">
                        {m.photo ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={m.photo} alt="" className="h-full w-full object-cover" />
                        ) : (
                          m.full_name
                            .split(" ")
                            .map((p) => p[0])
                            .join("")
                            .slice(0, 2)
                            .toUpperCase()
                        )}
                      </div>
                    </td>
                    <td className="px-5 py-3.5 font-mono text-primary-800">{m.member_number}</td>
                    <td className="px-5 py-3.5 font-medium text-primary-900">{m.full_name}</td>
                    <td className="px-5 py-3.5 text-primary-700">
                      {categoryLabel[m.category] ?? m.category}
                    </td>
                    <td className="px-5 py-3.5 text-primary-700">{m.phone_number}</td>
                    <td className="px-5 py-3.5">
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
        </div>
      )}
    </div>
  );
}
