"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  AlertTriangle,
  ArrowLeft,
  Ban,
  CheckCircle2,
  Clock,
  Gavel,
  HandCoins,
  Receipt,
  Smartphone,
  UserPlus,
  Wallet,
  XCircle,
} from "lucide-react";
import { Link } from "@/i18n/navigation";
import { apiFetch, ApiError } from "@/lib/api";
import { useTenantProfile } from "@/lib/TenantProfileContext";
import { LoanStatusBadge } from "../page";

type MemberOption = { id: string; full_name: string; member_number: string };
type SavingsProductOption = { id: string; name: string };

type LoanGuarantorData = {
  id: string;
  guarantor: string;
  guarantor_name: string;
  guarantor_member_number: string;
  pledged_amount: string;
  status: "PENDING" | "CONSENTED" | "DECLINED" | "RELEASED";
};

type ScheduleRow = {
  id: string;
  installment_number: number;
  due_date: string;
  principal_due: string;
  interest_due: string;
  principal_paid: string;
  interest_paid: string;
  total_due: string;
  is_paid: boolean;
};

type RepaymentRow = {
  id: string;
  amount: string;
  transaction_date: string;
  created_at: string;
  description: string;
};

type ArrearsStatus = {
  is_overdue: boolean;
  days_overdue: number;
  bucket: string;
  amount_overdue: string;
};

type LoanDetail = {
  id: string;
  member: string;
  member_name: string;
  member_number: string;
  product_name: string;
  amount_requested: string;
  term_months: number;
  purpose: string;
  interest_method: string;
  interest_rate: string;
  status: string;
  applied_at: string;
  appraised_by_name: string | null;
  appraisal_notes: string;
  decided_by_name: string | null;
  decision_notes: string;
  guarantors: LoanGuarantorData[];
  disbursed_at: string | null;
  disbursement_method: string;
  closed_at: string | null;
  defaulted_at: string | null;
  default_notes: string;
  schedule: ScheduleRow[];
  repayments: RepaymentRow[];
  outstanding_balance: number;
  arrears: ArrearsStatus;
};

function errorDetail(err: unknown, fallback: string) {
  if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
    const detail = (err.body as { detail?: string }).detail;
    if (detail) return detail;
  }
  return fallback;
}

export default function LoanDetailPage() {
  const t = useTranslations("Loans");
  const { hasPermission } = useTenantProfile();
  const params = useParams<{ id: string }>();
  const [loan, setLoan] = useState<LoanDetail | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "error">("loading");
  const [members, setMembers] = useState<MemberOption[]>([]);

  const [myMemberId, setMyMemberId] = useState<string | null>(null);

  const [guarantorId, setGuarantorId] = useState("");
  const [guarantorMemberNumber, setGuarantorMemberNumber] = useState("");
  const [pledgedAmount, setPledgedAmount] = useState("");
  const [addingGuarantor, setAddingGuarantor] = useState(false);
  const [addGuarantorError, setAddGuarantorError] = useState("");

  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");

  const [appraisalNotes, setAppraisalNotes] = useState("");
  const [appraising, setAppraising] = useState(false);
  const [appraiseError, setAppraiseError] = useState("");

  const [decisionNotes, setDecisionNotes] = useState("");
  const [deciding, setDeciding] = useState(false);
  const [decideError, setDecideError] = useState("");

  const [savingsProducts, setSavingsProducts] = useState<SavingsProductOption[]>([]);
  const [disburseProductId, setDisburseProductId] = useState("");
  const [disbursePhoneNumber, setDisbursePhoneNumber] = useState("");
  const [disbursing, setDisbursing] = useState(false);
  const [disburseError, setDisburseError] = useState("");

  const [repayAmount, setRepayAmount] = useState("");
  const [repayDate, setRepayDate] = useState("");
  const [repayDescription, setRepayDescription] = useState("");
  const [repaying, setRepaying] = useState(false);
  const [repayError, setRepayError] = useState("");

  const [defaultNotes, setDefaultNotes] = useState("");
  const [defaulting, setDefaulting] = useState(false);
  const [defaultError, setDefaultError] = useState("");

  function load() {
    apiFetch<LoanDetail>(`/api/loans/${params.id}/`)
      .then((data) => {
        setLoan(data);
        setState("ready");
      })
      .catch(() => setState("error"));
  }

  useEffect(() => {
    load();
    if (hasPermission("loans.manage_guarantor_pledge")) {
      apiFetch<{ results: MemberOption[] }>("/api/members/")
        .then((data) => setMembers(data.results))
        .catch(() => {});
    }
    if (hasPermission("loans.disburse")) {
      apiFetch<{ results: SavingsProductOption[] }>("/api/savings/products/")
        .then((data) => setSavingsProducts(data.results))
        .catch(() => {});
    }
    // 404s for staff with no linked member record - that's expected, not an error.
    apiFetch<{ id: string }>("/api/members/me/")
      .then((data) => setMyMemberId(data.id))
      .catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.id]);

  async function handleAddGuarantor() {
    const usingDropdown = hasPermission("loans.manage_guarantor_pledge");
    if (usingDropdown ? !guarantorId : !guarantorMemberNumber) return;
    if (!pledgedAmount) return;
    setAddingGuarantor(true);
    setAddGuarantorError("");
    try {
      await apiFetch(`/api/loans/${params.id}/guarantors/`, {
        method: "POST",
        body: JSON.stringify(
          usingDropdown
            ? { guarantor: guarantorId, pledged_amount: pledgedAmount }
            : { guarantor_member_number: guarantorMemberNumber, pledged_amount: pledgedAmount }
        ),
      });
      setGuarantorId("");
      setGuarantorMemberNumber("");
      setPledgedAmount("");
      load();
    } catch (err) {
      setAddGuarantorError(errorDetail(err, t("error")));
    } finally {
      setAddingGuarantor(false);
    }
  }

  async function handleSubmitForAppraisal() {
    setSubmitting(true);
    setSubmitError("");
    try {
      await apiFetch(`/api/loans/${params.id}/submit/`, { method: "POST" });
      load();
    } catch (err) {
      setSubmitError(errorDetail(err, t("error")));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleAppraise() {
    setAppraising(true);
    setAppraiseError("");
    try {
      await apiFetch(`/api/loans/${params.id}/appraise/`, {
        method: "POST",
        body: JSON.stringify({ notes: appraisalNotes }),
      });
      setAppraisalNotes("");
      load();
    } catch (err) {
      setAppraiseError(errorDetail(err, t("error")));
    } finally {
      setAppraising(false);
    }
  }

  async function handleDecide(approved: boolean) {
    setDeciding(true);
    setDecideError("");
    try {
      await apiFetch(`/api/loans/${params.id}/decide/`, {
        method: "POST",
        body: JSON.stringify({ approved, notes: decisionNotes }),
      });
      setDecisionNotes("");
      load();
    } catch (err) {
      setDecideError(errorDetail(err, t("error")));
    } finally {
      setDeciding(false);
    }
  }

  async function handleDisburseToSavings() {
    if (!disburseProductId) return;
    setDisbursing(true);
    setDisburseError("");
    try {
      await apiFetch(`/api/loans/${params.id}/disburse/savings/`, {
        method: "POST",
        body: JSON.stringify({ product: disburseProductId }),
      });
      load();
    } catch (err) {
      setDisburseError(errorDetail(err, t("error")));
    } finally {
      setDisbursing(false);
    }
  }

  async function handleDisburseMobileMoney() {
    if (!disbursePhoneNumber) return;
    setDisbursing(true);
    setDisburseError("");
    try {
      await apiFetch(`/api/loans/${params.id}/disburse/mobile-money/`, {
        method: "POST",
        body: JSON.stringify({ phone_number: disbursePhoneNumber }),
      });
      load();
    } catch (err) {
      setDisburseError(errorDetail(err, t("error")));
    } finally {
      setDisbursing(false);
    }
  }

  async function handleRecordRepayment() {
    if (!repayAmount || !repayDate) return;
    setRepaying(true);
    setRepayError("");
    try {
      await apiFetch(`/api/loans/${params.id}/repay/`, {
        method: "POST",
        body: JSON.stringify({
          amount: repayAmount,
          transaction_date: repayDate,
          description: repayDescription,
        }),
      });
      setRepayAmount("");
      setRepayDate("");
      setRepayDescription("");
      load();
    } catch (err) {
      setRepayError(errorDetail(err, t("error")));
    } finally {
      setRepaying(false);
    }
  }

  async function handleMarkDefaulted() {
    setDefaulting(true);
    setDefaultError("");
    try {
      await apiFetch(`/api/loans/${params.id}/default/`, {
        method: "POST",
        body: JSON.stringify({ notes: defaultNotes }),
      });
      setDefaultNotes("");
      load();
    } catch (err) {
      setDefaultError(errorDetail(err, t("error")));
    } finally {
      setDefaulting(false);
    }
  }

  if (state === "loading") {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "error" || !loan) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  const availableMembers = members.filter(
    (m) => m.id !== loan.member && !loan.guarantors.some((g) => g.guarantor === m.id)
  );

  return (
    <div className="mx-auto max-w-2xl">
      <Link
        href="/loans"
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-primary-600 hover:text-primary-800"
      >
        <ArrowLeft size={16} />
        {t("backToLoans")}
      </Link>

      <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <div className="mb-4 flex items-start justify-between gap-3">
          <div>
            <h1 className="text-xl font-semibold text-primary-900">{loan.member_name}</h1>
            <p className="font-mono text-sm text-primary-500">{loan.member_number}</p>
          </div>
          <LoanStatusBadge status={loan.status} />
        </div>

        <dl className="divide-y divide-primary-50">
          <Row label={t("product")} value={loan.product_name} />
          <Row label={t("amount")} value={loan.amount_requested} />
          <Row label={t("term")} value={t("termMonths", { months: loan.term_months })} />
          {loan.purpose && <Row label={t("purpose")} value={loan.purpose} />}
          <Row
            label={t("interestMethod")}
            value={t(loan.interest_method === "FLAT" ? "methodFLAT" : "methodREDUCING_BALANCE")}
          />
        </dl>

        {loan.appraisal_notes && (
          <p className="mt-4 rounded-lg bg-primary-50 px-4 py-3 text-sm text-primary-700">
            {t("appraisedBy", { name: loan.appraised_by_name ?? "" })}: {loan.appraisal_notes}
          </p>
        )}
        {loan.decision_notes && (
          <p className="mt-2 rounded-lg bg-primary-50 px-4 py-3 text-sm text-primary-700">
            {t("decidedBy", { name: loan.decided_by_name ?? "" })}: {loan.decision_notes}
          </p>
        )}
      </div>

      <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <div className="mb-4 flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
            <UserPlus size={16} strokeWidth={2} />
          </div>
          <h2 className="text-sm font-semibold text-primary-900">{t("guarantors")}</h2>
        </div>

        {loan.guarantors.length === 0 ? (
          <p className="mb-4 text-sm text-primary-500">{t("noGuarantors")}</p>
        ) : (
          <ul className="mb-4 divide-y divide-primary-50">
            {loan.guarantors.map((g) => (
              <li key={g.id} className="flex items-center justify-between gap-3 py-2.5 first:pt-0">
                <div>
                  <p className="text-sm font-medium text-primary-900">{g.guarantor_name}</p>
                  <p className="font-mono text-xs text-primary-500">{g.guarantor_member_number}</p>
                </div>
                <div className="flex items-center gap-3">
                  <span className="font-mono text-sm text-primary-800">{g.pledged_amount}</span>
                  <span
                    className={
                      "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium " +
                      (g.status === "CONSENTED"
                        ? "bg-primary-100 text-primary-800"
                        : g.status === "DECLINED"
                          ? "bg-red-50 text-red-700"
                          : g.status === "RELEASED"
                            ? "bg-primary-50 text-primary-500"
                            : "bg-amber-100 text-amber-800")
                    }
                  >
                    {t(`guarantorStatus${g.status}`)}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        )}

        {loan.status === "PENDING_GUARANTORS" &&
          (hasPermission("loans.manage_guarantor_pledge") || myMemberId === loan.member) && (
          <div className="border-t border-primary-50 pt-4">
            <p className="mb-2 text-sm font-medium text-primary-900">{t("addGuarantor")}</p>
            <div className="flex flex-col gap-2 sm:flex-row">
              {hasPermission("loans.manage_guarantor_pledge") ? (
                <select
                  value={guarantorId}
                  onChange={(e) => setGuarantorId(e.target.value)}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                >
                  <option value="">{t("selectMember")}</option>
                  {availableMembers.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.full_name} ({m.member_number})
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type="text"
                  value={guarantorMemberNumber}
                  onChange={(e) => setGuarantorMemberNumber(e.target.value)}
                  placeholder={t("guarantorMemberNumber")}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                />
              )}
              <input
                type="number"
                min="0.01"
                step="0.01"
                value={pledgedAmount}
                onChange={(e) => setPledgedAmount(e.target.value)}
                placeholder={t("pledgedAmount")}
                className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
              />
              <button
                onClick={handleAddGuarantor}
                disabled={
                  addingGuarantor ||
                  (hasPermission("loans.manage_guarantor_pledge") ? !guarantorId : !guarantorMemberNumber) ||
                  !pledgedAmount
                }
                className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                {t("add")}
              </button>
            </div>
            {addGuarantorError && <p className="mt-2 text-xs text-red-600">{addGuarantorError}</p>}

            <button
              onClick={handleSubmitForAppraisal}
              disabled={submitting}
              className="mt-4 inline-flex items-center gap-2 rounded-full border border-primary-200 px-4 py-2 text-sm font-semibold text-primary-700 transition-colors hover:bg-primary-50 disabled:opacity-60"
            >
              <HandCoins size={16} />
              {t("submitForAppraisal")}
            </button>
            {submitError && <p className="mt-2 text-xs text-red-600">{submitError}</p>}
          </div>
        )}
      </div>

      {loan.status === "PENDING_APPRAISAL" && hasPermission("loans.appraise") && (
        <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <Gavel size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("appraise")}</h2>
          </div>
          <textarea
            value={appraisalNotes}
            onChange={(e) => setAppraisalNotes(e.target.value)}
            placeholder={t("appraisalNotesPlaceholder")}
            rows={3}
            className="mb-3 w-full rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
          />
          <button
            onClick={handleAppraise}
            disabled={appraising}
            className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            {t("appraise")}
          </button>
          {appraiseError && <p className="mt-2 text-xs text-red-600">{appraiseError}</p>}
        </div>
      )}

      {loan.status === "APPRAISED" && (hasPermission("loans.approve") || hasPermission("loans.reject")) && (
        <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <Gavel size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("decision")}</h2>
          </div>
          <textarea
            value={decisionNotes}
            onChange={(e) => setDecisionNotes(e.target.value)}
            placeholder={t("decisionNotes")}
            rows={3}
            className="mb-3 w-full rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
          />
          <div className="flex gap-2">
            {hasPermission("loans.approve") && (
              <button
                onClick={() => handleDecide(true)}
                disabled={deciding}
                className="inline-flex items-center gap-2 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                <CheckCircle2 size={16} />
                {t("approve")}
              </button>
            )}
            {hasPermission("loans.reject") && (
              <button
                onClick={() => handleDecide(false)}
                disabled={deciding}
                className="inline-flex items-center gap-2 rounded-full border border-red-200 px-4 py-2 text-sm font-semibold text-red-700 transition-colors hover:bg-red-50 disabled:opacity-60"
              >
                <XCircle size={16} />
                {t("reject")}
              </button>
            )}
          </div>
          {decideError && <p className="mt-2 text-xs text-red-600">{decideError}</p>}
        </div>
      )}

      {loan.status === "APPROVED" && hasPermission("loans.disburse") && (
        <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <Wallet size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("disburse")}</h2>
          </div>

          <p className="mb-2 text-sm font-medium text-primary-900">{t("disburseToSavings")}</p>
          <div className="mb-4 flex flex-col gap-2 sm:flex-row">
            <select
              value={disburseProductId}
              onChange={(e) => setDisburseProductId(e.target.value)}
              className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
            >
              <option value="">{t("selectSavingsProduct")}</option>
              {savingsProducts.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
            <button
              onClick={handleDisburseToSavings}
              disabled={disbursing || !disburseProductId}
              className="inline-flex items-center justify-center gap-2 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
            >
              <Wallet size={16} />
              {t("disburseToSavingsSubmit")}
            </button>
          </div>

          <p className="mb-2 border-t border-primary-50 pt-4 text-sm font-medium text-primary-900">
            {t("disburseMobileMoney")}
          </p>
          <div className="flex flex-col gap-2 sm:flex-row">
            <input
              type="tel"
              value={disbursePhoneNumber}
              onChange={(e) => setDisbursePhoneNumber(e.target.value)}
              placeholder={t("phoneNumber")}
              className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
            />
            <button
              onClick={handleDisburseMobileMoney}
              disabled={disbursing || !disbursePhoneNumber}
              className="inline-flex items-center justify-center gap-2 rounded-full border border-primary-200 px-4 py-2 text-sm font-semibold text-primary-700 transition-colors hover:bg-primary-50 disabled:opacity-60"
            >
              <Smartphone size={16} />
              {t("disburseMobileMoneySubmit")}
            </button>
          </div>
          {disburseError && <p className="mt-2 text-xs text-red-600">{disburseError}</p>}
        </div>
      )}

      {loan.status === "DISBURSED" && (
        <div className="mb-5 flex items-center gap-3 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="flex h-8 w-8 flex-none items-center justify-center rounded-lg bg-amber-50 text-amber-600">
            <Clock size={16} strokeWidth={2} />
          </div>
          <p className="text-sm text-primary-700">{t("disbursementPending")}</p>
        </div>
      )}

      {(loan.status === "ACTIVE" || loan.status === "CLOSED" || loan.status === "DEFAULTED") && (
        <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
                <Receipt size={16} strokeWidth={2} />
              </div>
              <h2 className="text-sm font-semibold text-primary-900">{t("schedule")}</h2>
            </div>
            <span className="font-mono text-sm font-semibold text-primary-900">
              {t("outstandingBalance")}: {loan.outstanding_balance}
            </span>
          </div>

          {loan.arrears.is_overdue && (
            <div className="mb-4 flex items-center gap-2.5 rounded-lg bg-red-50 px-4 py-3 text-sm text-red-700">
              <AlertTriangle size={16} className="flex-none" />
              {t("arrearsWarning", {
                days: loan.arrears.days_overdue,
                bucket: loan.arrears.bucket,
                amount: loan.arrears.amount_overdue,
              })}
            </div>
          )}

          {loan.closed_at && (
            <p className="mb-4 rounded-lg bg-primary-50 px-4 py-3 text-sm text-primary-700">
              {t("closedAt", { date: new Date(loan.closed_at).toLocaleDateString() })}
            </p>
          )}
          {loan.defaulted_at && (
            <p className="mb-4 rounded-lg bg-red-50 px-4 py-3 text-sm text-red-700">
              {t("defaultedAt", { date: new Date(loan.defaulted_at).toLocaleDateString() })}
              {loan.default_notes && `: ${loan.default_notes}`}
            </p>
          )}

          <div className="mb-4 overflow-x-auto">
            <table className="w-full min-w-[520px] text-left text-sm">
              <thead>
                <tr className="border-b border-primary-100 text-xs font-medium uppercase tracking-wide text-primary-500">
                  <th className="py-2 pr-3">#</th>
                  <th className="py-2 pr-3">{t("dueDate")}</th>
                  <th className="py-2 pr-3 text-right">{t("principal")}</th>
                  <th className="py-2 pr-3 text-right">{t("interest")}</th>
                  <th className="py-2 pr-3 text-right">{t("totalDue")}</th>
                  <th className="py-2 pl-3 text-right">{t("paid")}</th>
                </tr>
              </thead>
              <tbody>
                {loan.schedule.map((row) => (
                  <tr key={row.id} className="border-b border-primary-50 last:border-0">
                    <td className="py-2 pr-3 text-primary-600">{row.installment_number}</td>
                    <td className="py-2 pr-3 text-primary-600">{row.due_date}</td>
                    <td className="py-2 pr-3 text-right font-mono text-primary-900">{row.principal_due}</td>
                    <td className="py-2 pr-3 text-right font-mono text-primary-900">{row.interest_due}</td>
                    <td className="py-2 pr-3 text-right font-mono font-medium text-primary-900">
                      {row.total_due}
                    </td>
                    <td className="py-2 pl-3 text-right">
                      {row.is_paid ? (
                        <CheckCircle2 size={16} className="ml-auto text-primary-600" />
                      ) : (
                        <span className="text-primary-300">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {loan.repayments.length > 0 && (
            <div className="mb-4">
              <p className="mb-2 text-sm font-medium text-primary-900">{t("repaymentHistory")}</p>
              <ul className="divide-y divide-primary-50">
                {loan.repayments.map((r) => (
                  <li key={r.id} className="flex items-center justify-between gap-3 py-2 text-sm">
                    <span className="text-primary-600">{r.transaction_date}</span>
                    <span className="font-mono text-primary-900">{r.amount}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {loan.status === "ACTIVE" && hasPermission("loans.repay") && (
            <div className="border-t border-primary-50 pt-4">
              <p className="mb-2 text-sm font-medium text-primary-900">{t("recordRepayment")}</p>
              <div className="flex flex-col gap-2 sm:flex-row">
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={repayAmount}
                  onChange={(e) => setRepayAmount(e.target.value)}
                  placeholder={t("amount")}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                />
                <input
                  type="date"
                  value={repayDate}
                  onChange={(e) => setRepayDate(e.target.value)}
                  className="rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                />
              </div>
              <input
                type="text"
                value={repayDescription}
                onChange={(e) => setRepayDescription(e.target.value)}
                placeholder={t("descriptionOptional")}
                className="mt-2 w-full rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
              />
              <button
                onClick={handleRecordRepayment}
                disabled={repaying || !repayAmount || !repayDate}
                className="mt-3 inline-flex items-center gap-2 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                <Receipt size={16} />
                {t("recordRepaymentSubmit")}
              </button>
              {repayError && <p className="mt-2 text-xs text-red-600">{repayError}</p>}
            </div>
          )}

          {loan.status === "ACTIVE" && hasPermission("loans.approve") && (
            <div className="mt-4 border-t border-primary-50 pt-4">
              <p className="mb-2 text-sm font-medium text-primary-900">{t("markDefaulted")}</p>
              <textarea
                value={defaultNotes}
                onChange={(e) => setDefaultNotes(e.target.value)}
                placeholder={t("defaultNotesPlaceholder")}
                rows={2}
                className="mb-2 w-full rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
              />
              <button
                onClick={handleMarkDefaulted}
                disabled={defaulting}
                className="inline-flex items-center gap-2 rounded-full border border-red-200 px-4 py-2 text-sm font-semibold text-red-700 transition-colors hover:bg-red-50 disabled:opacity-60"
              >
                <Ban size={16} />
                {t("markDefaultedSubmit")}
              </button>
              {defaultError && <p className="mt-2 text-xs text-red-600">{defaultError}</p>}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4 py-2.5 first:pt-0 last:pb-0">
      <dt className="text-sm text-primary-500">{label}</dt>
      <dd className="text-right text-sm font-medium text-primary-900">{value}</dd>
    </div>
  );
}
