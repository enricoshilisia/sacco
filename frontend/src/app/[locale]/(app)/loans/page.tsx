"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { HandCoins } from "lucide-react";
import { Link } from "@/i18n/navigation";
import { apiFetch, ApiError } from "@/lib/api";

type LoanListItem = {
  id: string;
  member_name: string;
  member_number: string;
  product_name: string;
  amount_requested: string;
  term_months: number;
  status: string;
  applied_at: string;
};

const STATUS_STYLES: Record<string, string> = {
  PENDING_GUARANTORS: "bg-amber-100 text-amber-800",
  PENDING_APPRAISAL: "bg-amber-100 text-amber-800",
  APPRAISED: "bg-primary-50 text-primary-700",
  APPROVED: "bg-primary-100 text-primary-800",
  REJECTED: "bg-red-50 text-red-700",
};

export function LoanStatusBadge({ status }: { status: string }) {
  const t = useTranslations("Loans");
  return (
    <span
      className={
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium " +
        (STATUS_STYLES[status] ?? "bg-primary-50 text-primary-600")
      }
    >
      {t(`status${status}`)}
    </span>
  );
}

export default function LoansPage() {
  const t = useTranslations("Loans");
  const [loans, setLoans] = useState<LoanListItem[]>([]);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");

  useEffect(() => {
    apiFetch<{ results: LoanListItem[] }>("/api/loans/")
      .then((data) => {
        setLoans(data.results);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 403) setState("forbidden");
        else setState("forbidden");
      });
  }, []);

  return (
    <div>
      <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("title")}</h1>

      {state === "loading" && (
        <div className="flex justify-center py-16">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
        </div>
      )}

      {state === "forbidden" && (
        <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
          <p className="text-sm text-red-600">{t("forbidden")}</p>
        </div>
      )}

      {state === "ready" && loans.length === 0 && (
        <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
          <p className="text-sm text-primary-500">{t("noLoans")}</p>
        </div>
      )}

      {state === "ready" && loans.length > 0 && (
        <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-primary-100/80">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-left text-sm">
              <thead>
                <tr className="border-b border-primary-100 bg-primary-50/50 text-xs font-medium uppercase tracking-wide text-primary-500">
                  <th className="px-5 py-3">{t("member")}</th>
                  <th className="px-5 py-3">{t("product")}</th>
                  <th className="px-5 py-3 text-right">{t("amount")}</th>
                  <th className="px-5 py-3">{t("term")}</th>
                  <th className="px-5 py-3">{t("status")}</th>
                </tr>
              </thead>
              <tbody>
                {loans.map((loan) => (
                  <tr key={loan.id} className="border-b border-primary-50 last:border-0">
                    <td className="px-5 py-3.5">
                      <Link href={`/loans/${loan.id}`} className="font-medium text-primary-900 hover:underline">
                        {loan.member_name}
                      </Link>
                      <p className="font-mono text-xs text-primary-500">{loan.member_number}</p>
                    </td>
                    <td className="px-5 py-3.5 text-primary-600">{loan.product_name}</td>
                    <td className="px-5 py-3.5 text-right font-mono text-primary-900">{loan.amount_requested}</td>
                    <td className="px-5 py-3.5 text-primary-600">{t("termMonths", { months: loan.term_months })}</td>
                    <td className="px-5 py-3.5">
                      <LoanStatusBadge status={loan.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {state === "ready" && (
        <p className="mt-4 flex items-center gap-1.5 text-xs text-primary-400">
          <HandCoins size={12} />
          {loans.length} {t("title").toLowerCase()}
        </p>
      )}
    </div>
  );
}
