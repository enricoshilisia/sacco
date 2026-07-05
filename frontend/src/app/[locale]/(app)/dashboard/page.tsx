"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import {
  ArrowRight,
  Check,
  Clock,
  Gavel,
  HandCoins,
  Handshake,
  PiggyBank,
  Scale,
  Users,
  Wallet,
  X,
} from "lucide-react";
import { Link } from "@/i18n/navigation";
import { useTenantProfile } from "@/lib/TenantProfileContext";
import { apiFetch } from "@/lib/api";
import { LoanStatusBadge } from "../loans/page";

type MemberListItem = {
  id: string;
  member_number: string;
  full_name: string;
  status: string;
};

type AccountBalance = {
  code: string;
  balance: string;
};

type TrialBalance = {
  accounts: AccountBalance[];
  balanced: boolean;
};

type JournalLine = { debit: string; credit: string };

type JournalEntryLite = {
  id: string;
  reference: string;
  description: string;
  entry_date: string;
  lines: JournalLine[];
};

type MyMemberData = {
  member_number: string;
};

type MyStatement = {
  shares: { balance: string };
  savings_accounts: { id: string; product_name: string; balance: string }[];
};

type MyLoan = {
  id: string;
  product_name: string;
  amount_requested: string;
  term_months: number;
  status: string;
};

type GuaranteeRequest = {
  id: string;
  borrower_name: string;
  pledged_amount: string;
  status: "PENDING" | "CONSENTED" | "DECLINED" | "RELEASED";
};

const SHARE_CAPITAL_CODE = "3000";
const SAVINGS_CONTROL_CODE = "2000";

function money(value: number, currency: string) {
  return `${currency} ${value.toLocaleString(undefined, { maximumFractionDigits: 0 })}`;
}

const ACCOUNTING_PERMISSIONS = ["accounting.view_trial_balance", "accounting.view_ledger"];

export default function DashboardPage() {
  const t = useTranslations("Dashboard");
  const tl = useTranslations("MyLoans");
  const { profile, hasPermission, hasAnyPermission } = useTenantProfile();
  const canViewMembers = hasPermission("members.view");
  const canViewAccounting = hasAnyPermission(ACCOUNTING_PERMISSIONS);

  const [memberCount, setMemberCount] = useState<number | null | undefined>(undefined);
  const [recentMembers, setRecentMembers] = useState<MemberListItem[]>([]);
  const [trialBalance, setTrialBalance] = useState<TrialBalance | null | undefined>(undefined);
  const [journal, setJournal] = useState<JournalEntryLite[] | null | undefined>(undefined);
  const [myMember, setMyMember] = useState<MyMemberData | null | undefined>(undefined);
  const [myStatement, setMyStatement] = useState<MyStatement | null | undefined>(undefined);
  const [myLoans, setMyLoans] = useState<MyLoan[]>([]);
  const [guaranteeRequests, setGuaranteeRequests] = useState<GuaranteeRequest[]>([]);
  const [respondingId, setRespondingId] = useState<string | null>(null);

  function loadGuaranteeRequests() {
    apiFetch<{ results: GuaranteeRequest[] }>("/api/loans/me/guarantee-requests/")
      .then((data) => setGuaranteeRequests(data.results))
      .catch(() => {});
  }

  async function handleRespond(id: string, accept: boolean) {
    setRespondingId(id);
    try {
      await apiFetch(`/api/loans/guarantors/${id}/respond/`, {
        method: "POST",
        body: JSON.stringify({ accept }),
      });
      loadGuaranteeRequests();
    } finally {
      setRespondingId(null);
    }
  }

  useEffect(() => {
    // Org-wide SACCO data - only fetched (and only ever shown) to logins
    // that actually hold the relevant staff permission, so a self-service
    // member's dashboard never even requests, let alone renders, numbers
    // about the whole SACCO.
    if (canViewMembers) {
      apiFetch<{ count: number; results: MemberListItem[] }>("/api/members/")
        .then((data) => {
          setMemberCount(data.count);
          setRecentMembers(data.results.slice(0, 5));
        })
        .catch(() => setMemberCount(null));
    }

    if (canViewAccounting) {
      apiFetch<TrialBalance>("/api/accounting/trial-balance/")
        .then(setTrialBalance)
        .catch(() => setTrialBalance(null));

      apiFetch<{ results: JournalEntryLite[] }>("/api/accounting/journal-entries/")
        .then((data) => setJournal(data.results.slice(0, 5)))
        .catch(() => setJournal(null));
    }

    // Self-service: only succeeds if this login is linked to a member
    // record (see members.views.MyMemberView) - a pure staff account gets
    // a clean 404 here, so this section simply doesn't render for them.
    apiFetch<MyMemberData>("/api/members/me/")
      .then((data) => {
        setMyMember(data);
        apiFetch<MyStatement>("/api/savings/me/statement/")
          .then(setMyStatement)
          .catch(() => setMyStatement(null));
        apiFetch<{ results: MyLoan[] }>("/api/loans/me/")
          .then((loansData) => setMyLoans(loansData.results))
          .catch(() => {});
      })
      .catch(() => setMyMember(null));

    loadGuaranteeRequests();
  }, [canViewMembers, canViewAccounting]);

  if (!profile) return null;

  const { tenant, user } = profile;
  const fullName = `${user.first_name} ${user.last_name}`.trim();

  const shareCapital = trialBalance?.accounts.find((a) => a.code === SHARE_CAPITAL_CODE);
  const totalSavings = trialBalance?.accounts.find((a) => a.code === SAVINGS_CONTROL_CODE);

  return (
    <div>
      <p className="mb-6 text-xl font-semibold text-primary-900">
        {t("welcome", { name: fullName || user.phone_number })}
      </p>

      {myMember && (
        <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                <Wallet size={16} strokeWidth={2} />
              </div>
              <h2 className="text-sm font-semibold text-primary-900">{t("myAccount")}</h2>
            </div>
            <div className="flex items-center gap-3">
              <span className="font-mono text-xs text-primary-500">{myMember.member_number}</span>
              <Link
                href="/savings"
                className="inline-flex items-center gap-1 text-xs font-medium text-primary-600 hover:underline"
              >
                {t("manage")}
                <ArrowRight size={12} />
              </Link>
            </div>
          </div>

          {myStatement === undefined ? (
            <div className="flex justify-center py-6">
              <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
              <div>
                <p className="mb-1 text-xs text-primary-500">{t("myShares")}</p>
                <p className="text-lg font-semibold text-primary-900">
                  {money(Number(myStatement?.shares.balance ?? 0), tenant.currency)}
                </p>
              </div>
              {myStatement?.savings_accounts.map((acc) => (
                <div key={acc.id}>
                  <p className="mb-1 truncate text-xs text-primary-500">{acc.product_name}</p>
                  <p className="text-lg font-semibold text-primary-900">
                    {money(Number(acc.balance), tenant.currency)}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {myMember && (
        <div className="mb-6 grid gap-5 lg:grid-cols-2">
          <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
            <div className="mb-4 flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                  <HandCoins size={16} strokeWidth={2} />
                </div>
                <h2 className="text-sm font-semibold text-primary-900">{tl("title")}</h2>
              </div>
              <Link
                href="/loans"
                className="inline-flex items-center gap-1 text-xs font-medium text-primary-600 hover:underline"
              >
                {t("viewAll")}
                <ArrowRight size={12} />
              </Link>
            </div>

            {myLoans.length === 0 ? (
              <p className="text-sm text-primary-500">{tl("noLoans")}</p>
            ) : (
              <ul className="divide-y divide-primary-50">
                {myLoans.slice(0, 3).map((loan) => (
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

          {guaranteeRequests.length > 0 && (
            <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
              <div className="mb-4 flex items-center gap-2.5">
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                  <Handshake size={16} strokeWidth={2} />
                </div>
                <h2 className="text-sm font-semibold text-primary-900">{tl("guaranteeRequestsTitle")}</h2>
              </div>
              <ul className="divide-y divide-primary-50">
                {guaranteeRequests.map((req) => (
                  <li key={req.id} className="py-2.5 first:pt-0 last:pb-0">
                    <p className="text-sm text-primary-700">
                      {tl("pledgeFor", { name: req.borrower_name, amount: req.pledged_amount })}
                    </p>
                    {req.status === "PENDING" ? (
                      <div className="mt-2 flex gap-2">
                        <button
                          onClick={() => handleRespond(req.id, true)}
                          disabled={respondingId === req.id}
                          className="inline-flex items-center gap-1.5 rounded-full bg-primary-600 px-3 py-1.5 text-xs font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
                        >
                          <Check size={13} />
                          {tl("accept")}
                        </button>
                        <button
                          onClick={() => handleRespond(req.id, false)}
                          disabled={respondingId === req.id}
                          className="inline-flex items-center gap-1.5 rounded-full border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-700 transition-colors hover:bg-red-50 disabled:opacity-60"
                        >
                          <X size={13} />
                          {tl("decline")}
                        </button>
                      </div>
                    ) : (
                      <span className="mt-1 inline-block text-xs font-medium text-primary-500">
                        {req.status === "CONSENTED" && "✓"}
                        {req.status === "DECLINED" && "✗"}
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            </section>
          )}
        </div>
      )}

      {/* Live stats - SACCO-wide, so only for logins with the matching staff permission */}
      {(canViewMembers || canViewAccounting) && (
        <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
          {canViewMembers && (
            <StatCard
              icon={Users}
              label={t("totalMembers")}
              value={memberCount === null || memberCount === undefined ? undefined : memberCount.toLocaleString()}
            />
          )}
          {canViewAccounting && (
            <StatCard
              icon={Wallet}
              label={t("shareCapital")}
              value={
                trialBalance === null || trialBalance === undefined
                  ? undefined
                  : money(Number(shareCapital?.balance ?? 0), tenant.currency)
              }
            />
          )}
          {canViewAccounting && (
            <StatCard
              icon={PiggyBank}
              label={t("totalSavings")}
              value={
                trialBalance === null || trialBalance === undefined
                  ? undefined
                  : money(Number(totalSavings?.balance ?? 0), tenant.currency)
              }
            />
          )}
          {canViewAccounting && (
            <StatCard
              icon={Scale}
              label={t("ledgerStatus")}
              value={
                trialBalance === null || trialBalance === undefined
                  ? undefined
                  : trialBalance.balanced
                    ? t("balanced")
                    : t("unbalanced")
              }
              tone={trialBalance && !trialBalance.balanced ? "warn" : "default"}
            />
          )}
        </div>
      )}

      {/* Live activity - same staff-only scope as the stats above */}
      {(canViewMembers || canViewAccounting) && (
        <div className="mb-6 grid gap-5 lg:grid-cols-2">
          {canViewMembers && (
            <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
              <div className="mb-4 flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                    <Users size={16} strokeWidth={2} />
                  </div>
                  <h2 className="text-sm font-semibold text-primary-900">{t("recentMembers")}</h2>
                </div>
                <Link
                  href="/members"
                  className="inline-flex items-center gap-1 text-xs font-medium text-primary-600 hover:underline"
                >
                  {t("viewAll")}
                  <ArrowRight size={12} />
                </Link>
              </div>
              {recentMembers.length === 0 ? (
                <p className="text-sm text-primary-500">{t("noRecentMembers")}</p>
              ) : (
                <ul className="divide-y divide-primary-50">
                  {recentMembers.map((m) => (
                    <li key={m.id} className="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0">
                      <div className="min-w-0">
                        <p className="truncate text-sm font-medium text-primary-900">{m.full_name}</p>
                        <p className="font-mono text-xs text-primary-500">{m.member_number}</p>
                      </div>
                      <span className="shrink-0 rounded-full bg-primary-50 px-2.5 py-1 text-xs font-medium text-primary-700">
                        {m.status}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )}

          {canViewAccounting && (
            <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
              <div className="mb-4 flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                    <Clock size={16} strokeWidth={2} />
                  </div>
                  <h2 className="text-sm font-semibold text-primary-900">{t("recentActivity")}</h2>
                </div>
                <Link
                  href="/accounting"
                  className="inline-flex items-center gap-1 text-xs font-medium text-primary-600 hover:underline"
                >
                  {t("viewAll")}
                  <ArrowRight size={12} />
                </Link>
              </div>
              {!journal || journal.length === 0 ? (
                <p className="text-sm text-primary-500">{t("noRecentActivity")}</p>
              ) : (
                <ul className="divide-y divide-primary-50">
                  {journal.map((entry) => {
                    const amount = entry.lines.reduce((sum, l) => sum + Number(l.debit), 0);
                    return (
                      <li key={entry.id} className="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0">
                        <div className="min-w-0">
                          <p className="truncate text-sm font-medium text-primary-900">{entry.description}</p>
                          <p className="font-mono text-xs text-primary-500">{entry.reference}</p>
                        </div>
                        <span className="shrink-0 font-mono text-sm text-primary-800">
                          {money(amount, tenant.currency)}
                        </span>
                      </li>
                    );
                  })}
                </ul>
              )}
            </section>
          )}
        </div>
      )}

      {/* Preview of not-yet-built modules - sample data only, clearly muted so it can never be mistaken for real numbers.
          Loans, Payments and Distributions used to be mock cards here too - removed once each shipped for real, so
          a genuinely-built feature is never shown sitting next to obviously-fake numbers. Staff-oriented preview of
          a SACCO-wide module, so same staff-only scope as the stats above. */}
      {(canViewMembers || canViewAccounting) && (
        <div>
          <h2 className="text-sm font-semibold text-primary-400">{t("comingSoon")}</h2>
          <p className="mb-4 text-xs text-primary-400">{t("comingSoonHelp")}</p>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <MockCard icon={Gavel} title={t("governanceTitle")}>
              <MockRow label={t("governanceNextMeeting")} value="9 Jul 2026" />
              <MockRow label={t("governanceResolutions")} value="2" />
              <MockRow label={t("governanceAttendance")} value="87%" />
            </MockCard>
          </div>
        </div>
      )}
    </div>
  );
}

function StatCard({
  icon: Icon,
  label,
  value,
  tone = "default",
}: {
  icon: typeof Users;
  label: string;
  value: string | undefined;
  tone?: "default" | "warn";
}) {
  return (
    <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100/80">
      <div
        className={
          "mb-3 flex h-9 w-9 items-center justify-center rounded-lg " +
          (tone === "warn" ? "bg-red-50 text-red-600" : "bg-primary-50 text-primary-600")
        }
      >
        <Icon size={18} strokeWidth={2} />
      </div>
      {value === undefined ? (
        <div className="mb-1 h-7 w-20 animate-pulse rounded bg-primary-50" />
      ) : (
        <p className={"text-xl font-semibold " + (tone === "warn" ? "text-red-700" : "text-primary-900")}>
          {value}
        </p>
      )}
      <p className="text-sm text-primary-500">{label}</p>
    </div>
  );
}

function MockCard({
  icon: Icon,
  title,
  children,
}: {
  icon: typeof HandCoins;
  title: string;
  children: React.ReactNode;
}) {
  const t = useTranslations("Dashboard");
  return (
    <div className="relative rounded-2xl border border-dashed border-primary-200 bg-primary-50/40 p-5">
      <span
        data-testid="preview-badge"
        className="absolute right-3 top-3 rounded-full bg-white px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-primary-400 ring-1 ring-primary-100"
      >
        {t("previewBadge")}
      </span>
      <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-primary-100/50 text-primary-300">
        <Icon size={18} strokeWidth={2} />
      </div>
      <h3 className="mb-3 text-sm font-semibold text-primary-400">{title}</h3>
      <dl className="space-y-2">{children}</dl>
    </div>
  );
}

function MockRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 text-sm">
      <dt className="text-primary-300">{label}</dt>
      <dd className="font-medium text-primary-400">{value}</dd>
    </div>
  );
}
