"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import {
  ArrowRight,
  Banknote,
  Building2,
  Clock,
  Gavel,
  HandCoins,
  Mail,
  MapPin,
  Phone,
  PiggyBank,
  Scale,
  Smartphone,
  User,
  Users,
  Wallet,
} from "lucide-react";
import { Link } from "@/i18n/navigation";
import { useTenantProfile } from "@/lib/TenantProfileContext";
import { apiFetch } from "@/lib/api";

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

const SHARE_CAPITAL_CODE = "3000";
const SAVINGS_CONTROL_CODE = "2000";

function money(value: number, currency: string) {
  return `${currency} ${value.toLocaleString(undefined, { maximumFractionDigits: 0 })}`;
}

export default function DashboardPage() {
  const t = useTranslations("Dashboard");
  const { profile } = useTenantProfile();

  const [memberCount, setMemberCount] = useState<number | null | undefined>(undefined);
  const [recentMembers, setRecentMembers] = useState<MemberListItem[]>([]);
  const [trialBalance, setTrialBalance] = useState<TrialBalance | null | undefined>(undefined);
  const [journal, setJournal] = useState<JournalEntryLite[] | null | undefined>(undefined);
  const [myMember, setMyMember] = useState<MyMemberData | null | undefined>(undefined);
  const [myStatement, setMyStatement] = useState<MyStatement | null | undefined>(undefined);

  useEffect(() => {
    apiFetch<{ count: number; results: MemberListItem[] }>("/api/members/")
      .then((data) => {
        setMemberCount(data.count);
        setRecentMembers(data.results.slice(0, 5));
      })
      .catch(() => setMemberCount(null));

    apiFetch<TrialBalance>("/api/accounting/trial-balance/")
      .then(setTrialBalance)
      .catch(() => setTrialBalance(null));

    apiFetch<{ results: JournalEntryLite[] }>("/api/accounting/journal-entries/")
      .then((data) => setJournal(data.results.slice(0, 5)))
      .catch(() => setJournal(null));

    // Self-service: only succeeds if this login is linked to a member
    // record (see members.views.MyMemberView) - a pure staff account gets
    // a clean 404 here, so this section simply doesn't render for them.
    apiFetch<MyMemberData>("/api/members/me/")
      .then((data) => {
        setMyMember(data);
        apiFetch<MyStatement>("/api/savings/me/statement/")
          .then(setMyStatement)
          .catch(() => setMyStatement(null));
      })
      .catch(() => setMyMember(null));
  }, []);

  if (!profile) return null;

  const { tenant, user, memberships } = profile;
  const fullName = `${user.first_name} ${user.last_name}`.trim();
  const primaryMembership = memberships[0];

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
            <span className="font-mono text-xs text-primary-500">{myMember.member_number}</span>
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

      {/* Live stats */}
      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        {memberCount !== null && (
          <StatCard
            icon={Users}
            label={t("totalMembers")}
            value={memberCount === undefined ? undefined : memberCount.toLocaleString()}
          />
        )}
        {trialBalance !== null && (
          <StatCard
            icon={Wallet}
            label={t("shareCapital")}
            value={
              trialBalance === undefined
                ? undefined
                : money(Number(shareCapital?.balance ?? 0), tenant.currency)
            }
          />
        )}
        {trialBalance !== null && (
          <StatCard
            icon={PiggyBank}
            label={t("totalSavings")}
            value={
              trialBalance === undefined
                ? undefined
                : money(Number(totalSavings?.balance ?? 0), tenant.currency)
            }
          />
        )}
        {trialBalance !== null && (
          <StatCard
            icon={Scale}
            label={t("ledgerStatus")}
            value={trialBalance === undefined ? undefined : trialBalance.balanced ? t("balanced") : t("unbalanced")}
            tone={trialBalance && !trialBalance.balanced ? "warn" : "default"}
          />
        )}
      </div>

      {/* Live activity */}
      {(memberCount || journal !== null) && (
        <div className="mb-6 grid gap-5 lg:grid-cols-2">
          {memberCount !== null && (
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

          {journal !== null && (
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

      <div className="mb-8 grid gap-5 lg:grid-cols-2">
        <Card icon={Building2} title={t("saccoProfile")}>
          <Row icon={MapPin} label={t("country")} value={tenant.country} />
          <Row icon={MapPin} label={t("currency")} value={tenant.currency} />
          <Row icon={MapPin} label={t("address")} value={tenant.address || t("notProvided")} />
          <Row icon={Mail} label={t("contactEmail")} value={tenant.contact_email || t("notProvided")} />
          <Row icon={Phone} label={t("contactPhone")} value={tenant.contact_phone || t("notProvided")} />
        </Card>

        <Card icon={User} title={t("yourProfile")}>
          <Row icon={Phone} label={t("phoneNumber")} value={user.phone_number} />
          <Row icon={Mail} label={t("email")} value={user.email || t("notProvided")} />
          {primaryMembership && (
            <>
              <Row icon={User} label={t("role")} value={primaryMembership.role_name} />
              <Row
                icon={User}
                label={t("jobTitle")}
                value={primaryMembership.job_title || t("notProvided")}
              />
            </>
          )}
        </Card>
      </div>

      {/* Preview of not-yet-built modules - sample data only, clearly muted so it can never be mistaken for real numbers. */}
      <div>
        <h2 className="text-sm font-semibold text-primary-400">{t("comingSoon")}</h2>
        <p className="mb-4 text-xs text-primary-400">{t("comingSoonHelp")}</p>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <MockCard icon={HandCoins} title={t("loansTitle")}>
            <MockRow label={t("loansActive")} value="128" />
            <MockRow label={t("loansPar")} value="2.3%" />
            <MockRow label={t("loansDisbursed")} value={`${tenant.currency} 4.2M`} />
          </MockCard>

          <MockCard icon={Smartphone} title={t("paymentsTitle")}>
            <MockRow label={t("paymentsToday")} value={`${tenant.currency} 340,200`} />
            <MockRow label={t("paymentsPending")} value="3" />
            <MockRow label={t("paymentsSuccessRate")} value="98.4%" />
          </MockCard>

          <MockCard icon={Banknote} title={t("distributionsTitle")}>
            <MockRow label={t("distributionsLast")} value="14 Dec 2025" />
            <MockRow label={t("distributionsTotal")} value={`${tenant.currency} 1.8M`} />
            <MockRow label={t("distributionsNextAgm")} value="22 Aug 2026" />
          </MockCard>

          <MockCard icon={Gavel} title={t("governanceTitle")}>
            <MockRow label={t("governanceNextMeeting")} value="9 Jul 2026" />
            <MockRow label={t("governanceResolutions")} value="2" />
            <MockRow label={t("governanceAttendance")} value="87%" />
          </MockCard>
        </div>
      </div>
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

function Card({
  icon: Icon,
  title,
  children,
}: {
  icon: typeof Building2;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
      <div className="mb-5 flex items-center gap-2.5">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
          <Icon size={16} strokeWidth={2} />
        </div>
        <h2 className="text-sm font-semibold text-primary-900">{title}</h2>
      </div>
      <dl className="divide-y divide-primary-50">{children}</dl>
    </section>
  );
}

function Row({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Building2;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center justify-between gap-4 py-2.5 first:pt-0 last:pb-0">
      <dt className="flex items-center gap-2 text-sm text-primary-500">
        <Icon size={14} className="shrink-0" />
        {label}
      </dt>
      <dd className="text-right text-sm font-medium text-primary-900">{value}</dd>
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
