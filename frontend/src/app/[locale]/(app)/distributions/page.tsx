"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Banknote, PiggyBank } from "lucide-react";
import { Link } from "@/i18n/navigation";
import { apiFetch, ApiError } from "@/lib/api";
import { useTenantProfile } from "@/lib/TenantProfileContext";

type RunListItem = {
  id: string;
  kind: "DIVIDEND" | "INTEREST";
  product_name: string | null;
  period_start: string;
  period_end: string;
  rate: string;
  status: "PENDING_APPROVAL" | "APPROVED" | "REJECTED";
  description: string;
  proposed_at: string;
  member_count: number;
};

type MyEntry = {
  id: string;
  run: string;
  member_name: string;
  member_number: string;
  basis_balance: string;
  gross_amount: string;
  wht_amount: string;
  net_amount: string;
  status: "PROPOSED" | "POSTED" | "PAID";
};

type SavingsProductOption = { id: string; name: string };

const RUN_STATUS_STYLES: Record<string, string> = {
  PENDING_APPROVAL: "bg-amber-100 text-amber-800",
  APPROVED: "bg-primary-100 text-primary-800",
  REJECTED: "bg-red-50 text-red-700",
};

const ENTRY_STATUS_STYLES: Record<string, string> = {
  PROPOSED: "bg-amber-100 text-amber-800",
  POSTED: "bg-primary-50 text-primary-700",
  PAID: "bg-primary-100 text-primary-800",
};

export function RunStatusBadge({ status }: { status: string }) {
  const t = useTranslations("Distributions");
  return (
    <span
      className={
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium " +
        (RUN_STATUS_STYLES[status] ?? "bg-primary-50 text-primary-600")
      }
    >
      {t(`status${status}`)}
    </span>
  );
}

export function EntryStatusBadge({ status }: { status: string }) {
  const t = useTranslations("Distributions");
  return (
    <span
      className={
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium " +
        (ENTRY_STATUS_STYLES[status] ?? "bg-primary-50 text-primary-600")
      }
    >
      {t(`entryStatus${status}`)}
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

export default function DistributionsPage() {
  const t = useTranslations("Distributions");
  const { hasPermission, myMemberId } = useTenantProfile();
  const isStaffView = hasPermission("distributions.view");
  const canProposeDividend = hasPermission("distributions.run_dividend");
  const canProposeInterest = hasPermission("distributions.run_interest");

  const [runs, setRuns] = useState<RunListItem[]>([]);
  const [myEntries, setMyEntries] = useState<MyEntry[]>([]);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");

  const [products, setProducts] = useState<SavingsProductOption[]>([]);

  const [divPeriodStart, setDivPeriodStart] = useState("");
  const [divPeriodEnd, setDivPeriodEnd] = useState("");
  const [divRate, setDivRate] = useState("");
  const [divDescription, setDivDescription] = useState("");
  const [proposingDividend, setProposingDividend] = useState(false);
  const [divError, setDivError] = useState("");

  const [intProductId, setIntProductId] = useState("");
  const [intPeriodStart, setIntPeriodStart] = useState("");
  const [intPeriodEnd, setIntPeriodEnd] = useState("");
  const [intRate, setIntRate] = useState("");
  const [intDescription, setIntDescription] = useState("");
  const [proposingInterest, setProposingInterest] = useState(false);
  const [intError, setIntError] = useState("");

  function loadRuns() {
    apiFetch<{ results: RunListItem[] }>("/api/distributions/runs/")
      .then((data) => {
        setRuns(data.results);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 403) setState("forbidden");
        else setState("forbidden");
      });
  }

  function loadMyEntries() {
    apiFetch<{ results: MyEntry[] }>("/api/distributions/me/")
      .then((data) => {
        setMyEntries(data.results);
        setState("ready");
      })
      .catch(() => setState("forbidden"));
  }

  useEffect(() => {
    if (isStaffView) {
      loadRuns();
      if (canProposeInterest) {
        apiFetch<{ results: SavingsProductOption[] }>("/api/savings/products/")
          .then((data) => setProducts(data.results))
          .catch(() => {});
      }
      return;
    }
    if (myMemberId) {
      loadMyEntries();
    }
  }, [isStaffView, myMemberId, canProposeInterest]);

  const effectiveState = state === "loading" && !isStaffView && myMemberId === null ? "forbidden" : state;

  async function handleProposeDividend() {
    if (!divPeriodStart || !divPeriodEnd || !divRate) return;
    setProposingDividend(true);
    setDivError("");
    try {
      await apiFetch("/api/distributions/runs/dividend/", {
        method: "POST",
        body: JSON.stringify({
          period_start: divPeriodStart,
          period_end: divPeriodEnd,
          rate: divRate,
          description: divDescription,
        }),
      });
      setDivPeriodStart("");
      setDivPeriodEnd("");
      setDivRate("");
      setDivDescription("");
      loadRuns();
    } catch (err) {
      setDivError(errorDetail(err, t("error")));
    } finally {
      setProposingDividend(false);
    }
  }

  async function handleProposeInterest() {
    if (!intProductId || !intPeriodStart || !intPeriodEnd) return;
    setProposingInterest(true);
    setIntError("");
    try {
      await apiFetch("/api/distributions/runs/interest/", {
        method: "POST",
        body: JSON.stringify({
          savings_product: intProductId,
          period_start: intPeriodStart,
          period_end: intPeriodEnd,
          rate: intRate || null,
          description: intDescription,
        }),
      });
      setIntProductId("");
      setIntPeriodStart("");
      setIntPeriodEnd("");
      setIntRate("");
      setIntDescription("");
      loadRuns();
    } catch (err) {
      setIntError(errorDetail(err, t("error")));
    } finally {
      setProposingInterest(false);
    }
  }

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
          {(canProposeDividend || canProposeInterest) && (
            <div className="mb-5 grid gap-5 lg:grid-cols-2">
              {canProposeDividend && (
                <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
                  <div className="mb-4 flex items-center gap-2.5">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                      <Banknote size={16} strokeWidth={2} />
                    </div>
                    <h2 className="text-sm font-semibold text-primary-900">{t("proposeDividendTitle")}</h2>
                  </div>
                  <div className="flex flex-col gap-2">
                    <div className="flex gap-2">
                      <input
                        type="date"
                        value={divPeriodStart}
                        onChange={(e) => setDivPeriodStart(e.target.value)}
                        placeholder={t("periodStart")}
                        disabled={proposingDividend}
                        className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                      />
                      <input
                        type="date"
                        value={divPeriodEnd}
                        onChange={(e) => setDivPeriodEnd(e.target.value)}
                        placeholder={t("periodEnd")}
                        disabled={proposingDividend}
                        className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                      />
                    </div>
                    <input
                      type="number"
                      min="0.0001"
                      step="0.0001"
                      value={divRate}
                      onChange={(e) => setDivRate(e.target.value)}
                      placeholder={t("rate")}
                      disabled={proposingDividend}
                      className="rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                    />
                    <input
                      type="text"
                      value={divDescription}
                      onChange={(e) => setDivDescription(e.target.value)}
                      placeholder={t("descriptionPlaceholder")}
                      disabled={proposingDividend}
                      className="rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                    />
                    <button
                      onClick={handleProposeDividend}
                      disabled={proposingDividend || !divPeriodStart || !divPeriodEnd || !divRate}
                      className="self-start rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
                    >
                      {t("submit")}
                    </button>
                    {divError && <p className="text-xs text-red-600">{divError}</p>}
                  </div>
                </section>
              )}

              {canProposeInterest && (
                <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
                  <div className="mb-4 flex items-center gap-2.5">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                      <PiggyBank size={16} strokeWidth={2} />
                    </div>
                    <h2 className="text-sm font-semibold text-primary-900">{t("proposeInterestTitle")}</h2>
                  </div>
                  <div className="flex flex-col gap-2">
                    <select
                      value={intProductId}
                      onChange={(e) => setIntProductId(e.target.value)}
                      disabled={proposingInterest}
                      className="rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                    >
                      <option value="">{t("selectProduct")}</option>
                      {products.map((p) => (
                        <option key={p.id} value={p.id}>
                          {p.name}
                        </option>
                      ))}
                    </select>
                    <div className="flex gap-2">
                      <input
                        type="date"
                        value={intPeriodStart}
                        onChange={(e) => setIntPeriodStart(e.target.value)}
                        placeholder={t("periodStart")}
                        disabled={proposingInterest}
                        className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                      />
                      <input
                        type="date"
                        value={intPeriodEnd}
                        onChange={(e) => setIntPeriodEnd(e.target.value)}
                        placeholder={t("periodEnd")}
                        disabled={proposingInterest}
                        className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                      />
                    </div>
                    <input
                      type="number"
                      min="0.0001"
                      step="0.0001"
                      value={intRate}
                      onChange={(e) => setIntRate(e.target.value)}
                      placeholder={t("rateOptional")}
                      disabled={proposingInterest}
                      className="rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                    />
                    <input
                      type="text"
                      value={intDescription}
                      onChange={(e) => setIntDescription(e.target.value)}
                      placeholder={t("descriptionPlaceholder")}
                      disabled={proposingInterest}
                      className="rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                    />
                    <button
                      onClick={handleProposeInterest}
                      disabled={proposingInterest || !intProductId || !intPeriodStart || !intPeriodEnd}
                      className="self-start rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
                    >
                      {t("submit")}
                    </button>
                    {intError && <p className="text-xs text-red-600">{intError}</p>}
                  </div>
                </section>
              )}
            </div>
          )}

          <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-primary-100/80">
            <div className="border-b border-primary-100 bg-primary-50/50 px-5 py-3">
              <h2 className="text-sm font-semibold text-primary-900">{t("runsTitle")}</h2>
            </div>
            {runs.length === 0 ? (
              <p className="p-8 text-center text-sm text-primary-500">{t("noRuns")}</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[720px] text-left text-sm">
                  <thead>
                    <tr className="border-b border-primary-100 text-xs font-medium uppercase tracking-wide text-primary-500">
                      <th className="px-5 py-3">{t("product")}</th>
                      <th className="px-5 py-3">{t("period")}</th>
                      <th className="px-5 py-3 text-right">{t("rateColumn")}</th>
                      <th className="px-5 py-3 text-right">{t("members")}</th>
                      <th className="px-5 py-3">{t("status")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {runs.map((run) => (
                      <tr key={run.id} className="border-b border-primary-50 last:border-0">
                        <td className="px-5 py-3.5">
                          <Link href={`/distributions/${run.id}`} className="font-medium text-primary-900 hover:underline">
                            {run.kind === "DIVIDEND" ? t("kindDIVIDEND") : run.product_name ?? t("kindINTEREST")}
                          </Link>
                        </td>
                        <td className="px-5 py-3.5 text-primary-600">
                          {run.period_start} &ndash; {run.period_end}
                        </td>
                        <td className="px-5 py-3.5 text-right font-mono text-primary-900">{run.rate}</td>
                        <td className="px-5 py-3.5 text-right text-primary-600">{run.member_count}</td>
                        <td className="px-5 py-3.5">
                          <RunStatusBadge status={run.status} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}

      {effectiveState === "ready" && !isStaffView && (
        <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-primary-100/80">
          <div className="border-b border-primary-100 bg-primary-50/50 px-5 py-3">
            <h2 className="text-sm font-semibold text-primary-900">{t("myDistributionsTitle")}</h2>
          </div>
          {myEntries.length === 0 ? (
            <p className="p-8 text-center text-sm text-primary-500">{t("noDistributions")}</p>
          ) : (
            <ul className="divide-y divide-primary-50">
              {myEntries.map((entry) => (
                <li key={entry.id} className="flex items-center justify-between gap-3 px-5 py-3.5">
                  <div>
                    <p className="font-mono text-sm font-medium text-primary-900">{entry.net_amount}</p>
                    <p className="text-xs text-primary-500">
                      {t("gross")} {entry.gross_amount} &middot; {t("wht")} {entry.wht_amount}
                    </p>
                  </div>
                  <EntryStatusBadge status={entry.status} />
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
