"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { BookOpen, CheckCircle2, RotateCcw, Scale, XCircle } from "lucide-react";
import { apiFetch, ApiError } from "@/lib/api";

type AccountRow = {
  id: string;
  code: string;
  name: string;
  account_type: string;
  is_control_account: boolean;
  balance: string;
};

type TrialBalance = {
  accounts: AccountRow[];
  total_debit_side: string;
  total_credit_side: string;
  balanced: boolean;
};

type JournalLine = {
  id: string;
  account_code: string;
  account_name: string;
  debit: string;
  credit: string;
  member_name: string | null;
  description: string;
};

type JournalEntry = {
  id: string;
  reference: string;
  description: string;
  entry_date: string;
  reverses: string | null;
  reverses_reference: string | null;
  created_at: string;
  lines: JournalLine[];
};

const TABS = [
  { key: "trialBalance", icon: Scale },
  { key: "journal", icon: BookOpen },
] as const;

type TabKey = (typeof TABS)[number]["key"];

export default function AccountingPage() {
  const t = useTranslations("Accounting");
  const [tab, setTab] = useState<TabKey>("trialBalance");

  return (
    <div>
      <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("title")}</h1>

      <div className="mb-6 flex gap-1 border-b border-primary-100">
        {TABS.map(({ key, icon: Icon }) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
            className={
              "flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-medium transition-colors " +
              (tab === key
                ? "border-primary-600 text-primary-700"
                : "border-transparent text-primary-500 hover:text-primary-700")
            }
          >
            <Icon size={16} />
            {t(`tab_${key}`)}
          </button>
        ))}
      </div>

      {tab === "trialBalance" && <TrialBalanceTab />}
      {tab === "journal" && <JournalTab />}
    </div>
  );
}

function TrialBalanceTab() {
  const t = useTranslations("Accounting");
  const [data, setData] = useState<TrialBalance | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");

  useEffect(() => {
    apiFetch<TrialBalance>("/api/accounting/trial-balance/")
      .then((d) => {
        setData(d);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 403) setState("forbidden");
        else setState("forbidden");
      });
  }, []);

  if (state === "loading") {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "forbidden" || !data) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  return (
    <div>
      <div
        className={
          "mb-4 flex items-center gap-2 rounded-2xl p-4 text-sm font-medium " +
          (data.balanced ? "bg-primary-50 text-primary-800" : "bg-red-50 text-red-700")
        }
      >
        {data.balanced ? <CheckCircle2 size={18} /> : <XCircle size={18} />}
        {data.balanced ? t("balanced") : t("unbalanced")}
        <span className="ml-auto font-mono">
          {t("totalDebits")}: {data.total_debit_side} · {t("totalCredits")}: {data.total_credit_side}
        </span>
      </div>

      <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-primary-100/80">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[560px] text-left text-sm">
            <thead>
              <tr className="border-b border-primary-100 bg-primary-50/50 text-xs font-medium uppercase tracking-wide text-primary-500">
                <th className="px-5 py-3">{t("code")}</th>
                <th className="px-5 py-3">{t("account")}</th>
                <th className="px-5 py-3">{t("accountType")}</th>
                <th className="px-5 py-3 text-right">{t("balance")}</th>
              </tr>
            </thead>
            <tbody>
              {data.accounts.map((a) => (
                <tr key={a.id} className="border-b border-primary-50 last:border-0">
                  <td className="px-5 py-3.5 font-mono text-primary-800">{a.code}</td>
                  <td className="px-5 py-3.5 font-medium text-primary-900">{a.name}</td>
                  <td className="px-5 py-3.5 text-primary-600">{a.account_type}</td>
                  <td className="px-5 py-3.5 text-right font-mono text-primary-900">{a.balance}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function JournalTab() {
  const t = useTranslations("Accounting");
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");
  const [reversingId, setReversingId] = useState<string | null>(null);
  const [reason, setReason] = useState("");

  function load() {
    apiFetch<{ results: JournalEntry[] }>("/api/accounting/journal-entries/")
      .then((d) => {
        setEntries(d.results);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 403) setState("forbidden");
        else setState("forbidden");
      });
  }

  useEffect(() => {
    load();
  }, []);

  async function handleReverse(id: string) {
    if (!reason) return;
    await apiFetch(`/api/accounting/journal-entries/${id}/reverse/`, {
      method: "POST",
      body: JSON.stringify({ reason }),
    });
    setReversingId(null);
    setReason("");
    load();
  }

  if (state === "loading") {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "forbidden") {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {entries.map((entry) => (
        <div key={entry.id} className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-3 flex items-center justify-between gap-3">
            <div>
              <p className="font-mono text-sm font-semibold text-primary-900">{entry.reference}</p>
              <p className="text-sm text-primary-600">{entry.description}</p>
              {entry.reverses_reference && (
                <p className="text-xs text-primary-400">
                  {t("reversalOf")} {entry.reverses_reference}
                </p>
              )}
            </div>
            <span className="shrink-0 text-xs text-primary-500">{entry.entry_date}</span>
          </div>

          <table className="w-full text-left text-sm">
            <tbody>
              {entry.lines.map((line) => (
                <tr key={line.id} className="border-t border-primary-50">
                  <td className="py-2 text-primary-700">
                    {line.account_code} {line.account_name}
                    {line.member_name && (
                      <span className="text-primary-400"> · {line.member_name}</span>
                    )}
                  </td>
                  <td className="py-2 text-right font-mono text-primary-900">
                    {line.debit !== "0.00" ? `Dr ${line.debit}` : `Cr ${line.credit}`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {!entry.reverses && (
            <div className="mt-3 border-t border-primary-50 pt-3">
              {reversingId === entry.id ? (
                <div className="flex flex-col gap-2 sm:flex-row">
                  <input
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                    placeholder={t("reverseReasonPlaceholder")}
                    className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                  />
                  <button
                    onClick={() => handleReverse(entry.id)}
                    disabled={!reason}
                    className="rounded-full bg-red-600 px-4 py-2 text-xs font-semibold text-white hover:bg-red-700 disabled:opacity-50"
                  >
                    {t("confirmReverse")}
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => setReversingId(entry.id)}
                  className="inline-flex items-center gap-1.5 text-xs font-medium text-red-600 hover:underline"
                >
                  <RotateCcw size={13} />
                  {t("reverse")}
                </button>
              )}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
