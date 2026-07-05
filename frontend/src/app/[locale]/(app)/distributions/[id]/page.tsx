"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { ArrowLeft, Banknote, Check, X } from "lucide-react";
import { Link } from "@/i18n/navigation";
import { apiFetch, ApiError } from "@/lib/api";
import { useTenantProfile } from "@/lib/TenantProfileContext";
import { EntryStatusBadge, RunStatusBadge } from "../page";

type Payout = {
  id: string;
  provider: string;
  status: "PENDING" | "SUCCESS" | "FAILED";
  provider_reference: string;
  phone_number: string;
  amount: string;
  failure_reason: string;
};

type EntryDetail = {
  id: string;
  member: string;
  member_name: string;
  member_number: string;
  basis_balance: string;
  gross_amount: string;
  wht_amount: string;
  net_amount: string;
  status: "PROPOSED" | "POSTED" | "PAID";
  latest_payout: Payout | null;
};

type RunDetail = {
  id: string;
  kind: "DIVIDEND" | "INTEREST";
  product_name: string | null;
  period_start: string;
  period_end: string;
  rate: string;
  wht_rate: string;
  wht_rates_confirmed_by_tax_adviser: boolean;
  status: "PENDING_APPROVAL" | "APPROVED" | "REJECTED";
  description: string;
  proposed_by_name: string | null;
  proposed_at: string;
  approved_by_name: string | null;
  approved_at: string | null;
  rejected_by_name: string | null;
  rejected_at: string | null;
  rejection_reason: string;
  entries: EntryDetail[];
  total_gross: string;
  total_wht: string;
  total_net: string;
  member_count: number;
};

function errorDetail(err: unknown, fallback: string) {
  if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
    const detail = (err.body as { detail?: string }).detail;
    if (detail) return detail;
  }
  return fallback;
}

export default function DistributionRunDetailPage() {
  const t = useTranslations("Distributions");
  const { hasPermission } = useTenantProfile();
  const params = useParams<{ id: string }>();

  const [run, setRun] = useState<RunDetail | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "error">("loading");

  const [deciding, setDeciding] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [decideError, setDecideError] = useState("");

  const [payingOutAll, setPayingOutAll] = useState(false);
  const [payoutAllMessage, setPayoutAllMessage] = useState("");
  const [payoutPhones, setPayoutPhones] = useState<Record<string, string>>({});
  const [payingOutEntry, setPayingOutEntry] = useState<Record<string, boolean>>({});
  const [payoutErrors, setPayoutErrors] = useState<Record<string, string>>({});

  function load() {
    apiFetch<RunDetail>(`/api/distributions/runs/${params.id}/`)
      .then((data) => {
        setRun(data);
        setState("ready");
      })
      .catch(() => setState("error"));
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.id]);

  async function handleApprove() {
    setDeciding(true);
    setDecideError("");
    try {
      await apiFetch(`/api/distributions/runs/${params.id}/approve/`, { method: "POST" });
      load();
    } catch (err) {
      setDecideError(errorDetail(err, t("error")));
    } finally {
      setDeciding(false);
    }
  }

  async function handleReject() {
    if (!rejectReason) return;
    setDeciding(true);
    setDecideError("");
    try {
      await apiFetch(`/api/distributions/runs/${params.id}/reject/`, {
        method: "POST",
        body: JSON.stringify({ reason: rejectReason }),
      });
      setShowRejectForm(false);
      setRejectReason("");
      load();
    } catch (err) {
      setDecideError(errorDetail(err, t("error")));
    } finally {
      setDeciding(false);
    }
  }

  async function handlePayoutAll() {
    setPayingOutAll(true);
    setPayoutAllMessage("");
    try {
      await apiFetch(`/api/distributions/runs/${params.id}/payout-all/`, { method: "POST" });
      setPayoutAllMessage(t("payoutAllQueued"));
    } finally {
      setPayingOutAll(false);
    }
  }

  async function handlePayoutEntry(entryId: string) {
    setPayingOutEntry((s) => ({ ...s, [entryId]: true }));
    setPayoutErrors((s) => ({ ...s, [entryId]: "" }));
    try {
      await apiFetch(`/api/distributions/entries/${entryId}/payout/`, {
        method: "POST",
        body: JSON.stringify({ phone_number: payoutPhones[entryId] ?? "" }),
      });
      load();
    } catch (err) {
      setPayoutErrors((s) => ({ ...s, [entryId]: errorDetail(err, t("error")) }));
    } finally {
      setPayingOutEntry((s) => ({ ...s, [entryId]: false }));
    }
  }

  if (state === "loading") {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "error" || !run) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  const title = run.kind === "DIVIDEND" ? t("kindDIVIDEND") : run.product_name ?? t("kindINTEREST");

  return (
    <div className="mx-auto max-w-4xl">
      <Link
        href="/distributions"
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-primary-600 hover:text-primary-800"
      >
        <ArrowLeft size={16} />
        {t("backToDistributions")}
      </Link>

      <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <div className="mb-4 flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <Banknote size={16} strokeWidth={2} />
            </div>
            <h1 className="text-lg font-semibold text-primary-900">{title}</h1>
          </div>
          <RunStatusBadge status={run.status} />
        </div>

        <div className="mb-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
          <div>
            <p className="mb-1 text-xs text-primary-500">{t("period")}</p>
            <p className="text-sm font-medium text-primary-900">
              {run.period_start} &ndash; {run.period_end}
            </p>
          </div>
          <div>
            <p className="mb-1 text-xs text-primary-500">{t("rateColumn")}</p>
            <p className="text-sm font-medium text-primary-900">{run.rate}</p>
          </div>
          <div>
            <p className="mb-1 text-xs text-primary-500">{t("totals")}</p>
            <p className="font-mono text-sm font-medium text-primary-900">{run.total_net}</p>
          </div>
          <div>
            <p className="mb-1 text-xs text-primary-500">{t("members")}</p>
            <p className="text-sm font-medium text-primary-900">{run.member_count}</p>
          </div>
        </div>

        {run.description && <p className="mb-2 text-sm text-primary-600">{run.description}</p>}
        {!run.wht_rates_confirmed_by_tax_adviser && (
          <p className="mb-2 text-xs text-amber-700">{t("notConfirmedByTaxAdviser")}</p>
        )}
        {run.proposed_by_name && (
          <p className="text-xs text-primary-500">{t("proposedBy", { name: run.proposed_by_name })}</p>
        )}
        {run.status === "APPROVED" && run.approved_by_name && (
          <p className="text-xs text-primary-500">{t("approvedBy", { name: run.approved_by_name })}</p>
        )}
        {run.status === "REJECTED" && (
          <>
            {run.rejected_by_name && (
              <p className="text-xs text-primary-500">{t("rejectedBy", { name: run.rejected_by_name })}</p>
            )}
            {run.rejection_reason && (
              <p className="text-xs text-red-600">{t("rejectionReason", { reason: run.rejection_reason })}</p>
            )}
          </>
        )}

        {run.status === "PENDING_APPROVAL" && hasPermission("distributions.approve_distribution") && (
          <div className="mt-4 border-t border-primary-50 pt-4">
            {!showRejectForm ? (
              <div className="flex gap-2">
                <button
                  onClick={handleApprove}
                  disabled={deciding}
                  className="inline-flex items-center gap-1.5 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
                >
                  <Check size={15} />
                  {t("approve")}
                </button>
                <button
                  onClick={() => setShowRejectForm(true)}
                  disabled={deciding}
                  className="inline-flex items-center gap-1.5 rounded-full border border-red-200 px-4 py-2 text-sm font-semibold text-red-700 transition-colors hover:bg-red-50 disabled:opacity-60"
                >
                  <X size={15} />
                  {t("reject")}
                </button>
              </div>
            ) : (
              <div className="flex flex-col gap-2 sm:flex-row">
                <input
                  type="text"
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder={t("rejectReasonPlaceholder")}
                  disabled={deciding}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                />
                <button
                  onClick={handleReject}
                  disabled={deciding || !rejectReason}
                  className="rounded-full bg-red-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-red-700 disabled:opacity-60"
                >
                  {t("confirmReject")}
                </button>
              </div>
            )}
            {decideError && <p className="mt-2 text-xs text-red-600">{decideError}</p>}
          </div>
        )}

        {run.status === "APPROVED" && hasPermission("distributions.disburse") && (
          <div className="mt-4 border-t border-primary-50 pt-4">
            <button
              onClick={handlePayoutAll}
              disabled={payingOutAll}
              className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
            >
              {t("payoutAll")}
            </button>
            {payoutAllMessage && <p className="mt-2 text-xs text-primary-600">{payoutAllMessage}</p>}
          </div>
        )}
      </div>

      <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-primary-100/80">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[820px] text-left text-sm">
            <thead>
              <tr className="border-b border-primary-100 bg-primary-50/50 text-xs font-medium uppercase tracking-wide text-primary-500">
                <th className="px-5 py-3">{t("member")}</th>
                <th className="px-5 py-3 text-right">{t("basisBalance")}</th>
                <th className="px-5 py-3 text-right">{t("gross")}</th>
                <th className="px-5 py-3 text-right">{t("wht")}</th>
                <th className="px-5 py-3 text-right">{t("net")}</th>
                <th className="px-5 py-3">{t("status")}</th>
                {run.status === "APPROVED" && hasPermission("distributions.disburse") && <th className="px-5 py-3" />}
              </tr>
            </thead>
            <tbody>
              {run.entries.map((entry) => (
                <tr key={entry.id} className="border-b border-primary-50 last:border-0">
                  <td className="px-5 py-3.5">
                    <p className="font-medium text-primary-900">{entry.member_name}</p>
                    <p className="font-mono text-xs text-primary-500">{entry.member_number}</p>
                  </td>
                  <td className="px-5 py-3.5 text-right font-mono text-primary-700">{entry.basis_balance}</td>
                  <td className="px-5 py-3.5 text-right font-mono text-primary-700">{entry.gross_amount}</td>
                  <td className="px-5 py-3.5 text-right font-mono text-primary-700">{entry.wht_amount}</td>
                  <td className="px-5 py-3.5 text-right font-mono text-primary-900">{entry.net_amount}</td>
                  <td className="px-5 py-3.5">
                    <EntryStatusBadge status={entry.status} />
                    {entry.latest_payout && entry.latest_payout.status === "FAILED" && (
                      <p className="mt-1 text-xs text-red-600">{entry.latest_payout.failure_reason}</p>
                    )}
                  </td>
                  {run.status === "APPROVED" && hasPermission("distributions.disburse") && (
                    <td className="px-5 py-3.5">
                      {entry.status === "POSTED" && (
                        <div className="flex items-center gap-2">
                          <input
                            type="tel"
                            value={payoutPhones[entry.id] ?? ""}
                            onChange={(e) => setPayoutPhones((s) => ({ ...s, [entry.id]: e.target.value }))}
                            placeholder={t("phoneNumberPlaceholder")}
                            disabled={payingOutEntry[entry.id]}
                            className="w-40 rounded-lg border border-primary-200 bg-white px-2 py-1.5 text-xs text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                          />
                          <button
                            onClick={() => handlePayoutEntry(entry.id)}
                            disabled={payingOutEntry[entry.id]}
                            className="shrink-0 rounded-full bg-primary-600 px-3 py-1.5 text-xs font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
                          >
                            {t("initiatePayout")}
                          </button>
                        </div>
                      )}
                      {payoutErrors[entry.id] && <p className="mt-1 text-xs text-red-600">{payoutErrors[entry.id]}</p>}
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
