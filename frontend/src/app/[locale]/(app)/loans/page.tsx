"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { HandCoins } from "lucide-react";
import { Link } from "@/i18n/navigation";
import { apiFetch, ApiError } from "@/lib/api";
import { useTenantProfile } from "@/lib/TenantProfileContext";

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

type LoanProductOption = { id: string; name: string };

const STATUS_STYLES: Record<string, string> = {
  PENDING_GUARANTORS: "bg-amber-100 text-amber-800",
  PENDING_APPRAISAL: "bg-amber-100 text-amber-800",
  APPRAISED: "bg-primary-50 text-primary-700",
  APPROVED: "bg-primary-100 text-primary-800",
  REJECTED: "bg-red-50 text-red-700",
  DISBURSED: "bg-amber-100 text-amber-800",
  ACTIVE: "bg-primary-100 text-primary-800",
  CLOSED: "bg-primary-50 text-primary-500",
  DEFAULTED: "bg-red-100 text-red-800",
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

function errorDetail(err: unknown, fallback: string) {
  if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
    const detail = (err.body as { detail?: string }).detail;
    if (detail) return detail;
  }
  return fallback;
}

export default function LoansPage() {
  const t = useTranslations("Loans");
  const { hasPermission, myMemberId } = useTenantProfile();
  const isStaffView = hasPermission("loans.view");

  const [loans, setLoans] = useState<LoanListItem[]>([]);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");

  const tal = useTranslations("ApplyLoan");
  const [loanProducts, setLoanProducts] = useState<LoanProductOption[]>([]);
  const [applyProductId, setApplyProductId] = useState("");
  const [applyAmount, setApplyAmount] = useState("");
  const [applyTerm, setApplyTerm] = useState("");
  const [applyPurpose, setApplyPurpose] = useState("");
  const [applying, setApplying] = useState(false);
  const [applyError, setApplyError] = useState("");

  function loadMyLoans() {
    apiFetch<{ results: LoanListItem[] }>("/api/loans/me/")
      .then((data) => {
        setLoans(data.results);
        setState("ready");
      })
      .catch(() => setState("forbidden"));
  }

  async function handleApplyForLoan() {
    if (!applyProductId || !applyAmount || !applyTerm) return;
    setApplying(true);
    setApplyError("");
    try {
      await apiFetch("/api/loans/me/apply/", {
        method: "POST",
        body: JSON.stringify({
          product: applyProductId,
          amount_requested: applyAmount,
          term_months: Number(applyTerm),
          purpose: applyPurpose,
        }),
      });
      setApplyProductId("");
      setApplyAmount("");
      setApplyTerm("");
      setApplyPurpose("");
      loadMyLoans();
    } catch (err) {
      setApplyError(errorDetail(err, tal("error")));
    } finally {
      setApplying(false);
    }
  }

  useEffect(() => {
    if (isStaffView) {
      apiFetch<{ results: LoanListItem[] }>("/api/loans/")
        .then((data) => {
          setLoans(data.results);
          setState("ready");
        })
        .catch((err) => {
          if (err instanceof ApiError && err.status === 403) setState("forbidden");
          else setState("forbidden");
        });
      return;
    }
    if (myMemberId) {
      loadMyLoans();
      apiFetch<{ results: LoanProductOption[] }>("/api/loans/products/")
        .then((data) => setLoanProducts(data.results))
        .catch(() => {});
    }
  }, [isStaffView, myMemberId]);

  // Confirmed: not staff-permitted and no linked member record either.
  // Derived at render time (rather than via setState in the effect above)
  // since it's a pure function of props already in scope.
  const effectiveState = state === "loading" && !isStaffView && myMemberId === null ? "forbidden" : state;

  return (
    <div>
      <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("title")}</h1>

      {effectiveState === "loading" && (
        <div className="flex justify-center py-16">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
        </div>
      )}

      {effectiveState === "forbidden" && (
        <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
          <p className="text-sm text-red-600">{t("forbidden")}</p>
        </div>
      )}

      {effectiveState === "ready" && isStaffView && (
        <>
          {loans.length === 0 ? (
            <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
              <p className="text-sm text-primary-500">{t("noLoans")}</p>
            </div>
          ) : (
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
                        <td className="px-5 py-3.5 text-right font-mono text-primary-900">
                          {loan.amount_requested}
                        </td>
                        <td className="px-5 py-3.5 text-primary-600">
                          {t("termMonths", { months: loan.term_months })}
                        </td>
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
          <p className="mt-4 flex items-center gap-1.5 text-xs text-primary-400">
            <HandCoins size={12} />
            {loans.length} {t("title").toLowerCase()}
          </p>
        </>
      )}

      {effectiveState === "ready" && !isStaffView && (
        <div className="grid gap-5 lg:grid-cols-2">
          <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
            <div className="mb-4 flex items-center gap-2.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                <HandCoins size={16} strokeWidth={2} />
              </div>
              <h2 className="text-sm font-semibold text-primary-900">{t("myLoansTitle")}</h2>
            </div>
            {loans.length === 0 ? (
              <p className="text-sm text-primary-500">{t("noLoans")}</p>
            ) : (
              <ul className="divide-y divide-primary-50">
                {loans.map((loan) => (
                  <li key={loan.id} className="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0">
                    <Link href={`/loans/${loan.id}`} className="min-w-0 hover:underline">
                      <p className="truncate text-sm font-medium text-primary-900">{loan.product_name}</p>
                      <p className="font-mono text-xs text-primary-500">{loan.amount_requested}</p>
                    </Link>
                    <LoanStatusBadge status={loan.status} />
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
            <div className="mb-4 flex items-center gap-2.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                <HandCoins size={16} strokeWidth={2} />
              </div>
              <h2 className="text-sm font-semibold text-primary-900">{tal("title")}</h2>
            </div>
            <div className="flex flex-col gap-3">
              <select
                value={applyProductId}
                onChange={(e) => setApplyProductId(e.target.value)}
                disabled={applying}
                className="rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
              >
                <option value="">{tal("selectProduct")}</option>
                {loanProducts.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
              <div className="flex gap-3">
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={applyAmount}
                  onChange={(e) => setApplyAmount(e.target.value)}
                  placeholder={tal("amount")}
                  disabled={applying}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                />
                <input
                  type="number"
                  min="1"
                  value={applyTerm}
                  onChange={(e) => setApplyTerm(e.target.value)}
                  placeholder={tal("term")}
                  disabled={applying}
                  className="w-28 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                />
              </div>
              <input
                type="text"
                value={applyPurpose}
                onChange={(e) => setApplyPurpose(e.target.value)}
                placeholder={tal("purpose")}
                disabled={applying}
                className="rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
              />
              <button
                onClick={handleApplyForLoan}
                disabled={applying || !applyProductId || !applyAmount || !applyTerm}
                className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                {tal("submit")}
              </button>
              {applyError && <p className="text-xs text-red-600">{applyError}</p>}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
