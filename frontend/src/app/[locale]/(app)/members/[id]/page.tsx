"use client";

import { useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";
import { useLocale, useTranslations } from "next-intl";
import {
  ArrowLeft,
  Camera,
  Check,
  CheckCircle2,
  Clock,
  Copy,
  HandCoins,
  KeyRound,
  PiggyBank,
  Smartphone,
  Users,
  Wallet,
} from "lucide-react";
import { Link, useRouter } from "@/i18n/navigation";
import { apiFetch, ApiError, getAccessToken } from "@/lib/api";
import { LoanStatusBadge } from "../../loans/page";
import { copyToClipboard } from "@/lib/clipboard";
import { useTenantProfile } from "@/lib/TenantProfileContext";

type SavingsProduct = {
  id: string;
  name: string;
  code: string;
  product_type: string;
  is_active: boolean;
};

type SavingsTransaction = {
  id: string;
  transaction_type: string;
  amount: string;
  transaction_date: string;
};

type SavingsAccountData = {
  id: string;
  product: string;
  product_name: string;
  account_number: string;
  balance: string;
  transactions: SavingsTransaction[];
};

type MemberStatement = {
  shares: {
    balance: string;
    contributions: { id: string; amount: string; transaction_date: string }[];
  };
  savings_accounts: SavingsAccountData[];
};

type PaymentCollectionData = {
  id: string;
  status: "PENDING" | "SUCCESS" | "FAILED" | "CANCELLED";
  amount: string;
  provider: string;
  provider_receipt: string;
  provider_reference: string;
  failure_reason: string;
};

type PortalInvite = {
  id: string;
  status: "pending" | "accepted" | "revoked" | "expired";
  invite_path: string;
};

type MemberLoanItem = {
  id: string;
  product_name: string;
  amount_requested: string;
  term_months: number;
  status: string;
};

type LoanProductOption = { id: string; name: string };

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function errorDetail(err: unknown, fallback: string) {
  if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
    const detail = (err.body as { detail?: string }).detail;
    if (detail) return detail;
  }
  return fallback;
}

type MemberDetail = {
  id: string;
  member_number: string;
  user: string | null;
  category: string;
  status: string;
  first_name: string;
  last_name: string;
  other_names: string;
  date_of_birth: string | null;
  gender: string;
  id_type: string;
  id_number: string;
  phone_number: string;
  email: string;
  physical_address: string;
  photo: string | null;
  is_kyc_verified: boolean;
  relations: {
    id: string;
    kind: string;
    full_name: string;
    relationship: string;
    phone_number: string;
    benefit_percentage: string | null;
  }[];
};

export default function MemberDetailPage() {
  const t = useTranslations("Members");
  const ts = useTranslations("Savings");
  const tc = useTranslations("CollectPayment");
  const tp = useTranslations("PortalAccess");
  const tl = useTranslations("Loans");
  const ta = useTranslations("ApplyLoan");
  const locale = useLocale();
  const { hasPermission } = useTenantProfile();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [member, setMember] = useState<MemberDetail | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "error">("loading");
  const [verifying, setVerifying] = useState(false);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);

  const [statement, setStatement] = useState<MemberStatement | null>(null);
  const [products, setProducts] = useState<SavingsProduct[]>([]);

  const [contributeAmount, setContributeAmount] = useState("");
  const [contributing, setContributing] = useState(false);
  const [contributeError, setContributeError] = useState("");

  const [depositAmounts, setDepositAmounts] = useState<Record<string, string>>({});
  const [withdrawAmounts, setWithdrawAmounts] = useState<Record<string, string>>({});
  const [txnBusy, setTxnBusy] = useState<Record<string, boolean>>({});
  const [txnError, setTxnError] = useState<Record<string, string>>({});

  const [newProductId, setNewProductId] = useState("");
  const [newAmount, setNewAmount] = useState("");
  const [opening, setOpening] = useState(false);
  const [openError, setOpenError] = useState("");

  const [collectProductId, setCollectProductId] = useState("");
  const [collectPhone, setCollectPhone] = useState("");
  const [collectAmount, setCollectAmount] = useState("");
  const [collecting, setCollecting] = useState(false);
  const [collectError, setCollectError] = useState("");
  const [collection, setCollection] = useState<PaymentCollectionData | null>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const [portalInvite, setPortalInvite] = useState<PortalInvite | null>(null);
  const [inviting, setInviting] = useState(false);
  const [inviteError, setInviteError] = useState("");
  const [linkCopied, setLinkCopied] = useState(false);

  const [loans, setLoans] = useState<MemberLoanItem[]>([]);
  const [loanProducts, setLoanProducts] = useState<LoanProductOption[]>([]);
  const [applyProductId, setApplyProductId] = useState("");
  const [applyAmount, setApplyAmount] = useState("");
  const [applyTerm, setApplyTerm] = useState("");
  const [applyPurpose, setApplyPurpose] = useState("");
  const [applying, setApplying] = useState(false);
  const [applyError, setApplyError] = useState("");

  useEffect(() => {
    return () => {
      if (pollRef.current) clearInterval(pollRef.current);
    };
  }, []);

  function loadStatement(memberId: string) {
    apiFetch<MemberStatement>(`/api/savings/members/${memberId}/statement/`)
      .then(setStatement)
      .catch(() => {});
  }

  useEffect(() => {
    if (!getAccessToken()) {
      router.replace("/login");
      return;
    }
    apiFetch<MemberDetail>(`/api/members/${params.id}/`)
      .then((data) => {
        setMember(data);
        setState("ready");
      })
      .catch((err) => {
        if (err instanceof ApiError && err.status === 401) router.replace("/login");
        else setState("error");
      });
    loadStatement(params.id);
    apiFetch<{ results: SavingsProduct[] }>("/api/savings/products/")
      .then((data) => setProducts(data.results))
      .catch(() => {});
    apiFetch<{ results: PortalInvite[] }>(`/api/members/portal-invites/?member=${params.id}`)
      .then((data) => setPortalInvite(data.results.find((i) => i.status === "pending") ?? null))
      .catch(() => {});
    loadLoans(params.id);
    apiFetch<{ results: LoanProductOption[] }>("/api/loans/products/")
      .then((data) => setLoanProducts(data.results))
      .catch(() => {});
  }, [params.id, router]);

  function loadLoans(memberId: string) {
    apiFetch<{ results: MemberLoanItem[] }>(`/api/loans/?member=${memberId}`)
      .then((data) => setLoans(data.results))
      .catch(() => {});
  }

  async function handleApplyForLoan() {
    if (!member || !applyProductId || !applyAmount || !applyTerm) return;
    setApplying(true);
    setApplyError("");
    try {
      await apiFetch(`/api/loans/members/${member.id}/apply/`, {
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
      loadLoans(member.id);
    } catch (err) {
      setApplyError(errorDetail(err, ta("error")));
    } finally {
      setApplying(false);
    }
  }

  async function handleInvitePortalAccess() {
    if (!member) return;
    setInviting(true);
    setInviteError("");
    try {
      const invite = await apiFetch<PortalInvite>(`/api/members/${member.id}/portal-invite/`, {
        method: "POST",
      });
      setPortalInvite(invite);
    } catch (err) {
      setInviteError(errorDetail(err, tp("error")));
    } finally {
      setInviting(false);
    }
  }

  async function handleCopyPortalLink() {
    if (!portalInvite) return;
    const url = `${window.location.origin}/${locale}${portalInvite.invite_path}`;
    const copied = await copyToClipboard(url);
    if (copied) {
      setLinkCopied(true);
      setTimeout(() => setLinkCopied(false), 2000);
    }
  }

  async function handleContribute() {
    if (!member || !contributeAmount) return;
    setContributing(true);
    setContributeError("");
    try {
      await apiFetch(`/api/savings/members/${member.id}/shares/contribute/`, {
        method: "POST",
        body: JSON.stringify({ amount: contributeAmount, transaction_date: todayIso() }),
      });
      setContributeAmount("");
      loadStatement(member.id);
    } catch (err) {
      setContributeError(errorDetail(err, ts("error")));
    } finally {
      setContributing(false);
    }
  }

  async function handleDeposit(account: SavingsAccountData) {
    if (!member) return;
    const amount = depositAmounts[account.id];
    if (!amount) return;
    setTxnBusy((s) => ({ ...s, [account.id]: true }));
    setTxnError((s) => ({ ...s, [account.id]: "" }));
    try {
      await apiFetch(`/api/savings/members/${member.id}/deposit/`, {
        method: "POST",
        body: JSON.stringify({ product: account.product, amount, transaction_date: todayIso() }),
      });
      setDepositAmounts((s) => ({ ...s, [account.id]: "" }));
      loadStatement(member.id);
    } catch (err) {
      setTxnError((s) => ({ ...s, [account.id]: errorDetail(err, ts("error")) }));
    } finally {
      setTxnBusy((s) => ({ ...s, [account.id]: false }));
    }
  }

  async function handleWithdraw(account: SavingsAccountData) {
    if (!member) return;
    const amount = withdrawAmounts[account.id];
    if (!amount) return;
    setTxnBusy((s) => ({ ...s, [account.id]: true }));
    setTxnError((s) => ({ ...s, [account.id]: "" }));
    try {
      await apiFetch(`/api/savings/members/${member.id}/withdraw/`, {
        method: "POST",
        body: JSON.stringify({ savings_account: account.id, amount, transaction_date: todayIso() }),
      });
      setWithdrawAmounts((s) => ({ ...s, [account.id]: "" }));
      loadStatement(member.id);
    } catch (err) {
      setTxnError((s) => ({ ...s, [account.id]: errorDetail(err, ts("insufficientBalance")) }));
    } finally {
      setTxnBusy((s) => ({ ...s, [account.id]: false }));
    }
  }

  async function handleOpenAccount() {
    if (!member || !newProductId || !newAmount) return;
    setOpening(true);
    setOpenError("");
    try {
      await apiFetch(`/api/savings/members/${member.id}/deposit/`, {
        method: "POST",
        body: JSON.stringify({ product: newProductId, amount: newAmount, transaction_date: todayIso() }),
      });
      setNewProductId("");
      setNewAmount("");
      loadStatement(member.id);
    } catch (err) {
      setOpenError(errorDetail(err, ts("error")));
    } finally {
      setOpening(false);
    }
  }

  function pollCollection(id: string, memberId: string) {
    if (pollRef.current) clearInterval(pollRef.current);
    pollRef.current = setInterval(async () => {
      try {
        const updated = await apiFetch<PaymentCollectionData>(`/api/payments/collections/${id}/`);
        setCollection(updated);
        if (updated.status !== "PENDING") {
          if (pollRef.current) clearInterval(pollRef.current);
          if (updated.status === "SUCCESS") loadStatement(memberId);
        }
      } catch {
        if (pollRef.current) clearInterval(pollRef.current);
      }
    }, 1500);
  }

  async function handleCollect() {
    if (!member || !collectProductId || !collectAmount) return;
    setCollecting(true);
    setCollectError("");
    setCollection(null);
    try {
      const created = await apiFetch<PaymentCollectionData>(`/api/payments/members/${member.id}/collect/`, {
        method: "POST",
        body: JSON.stringify({
          product: collectProductId,
          amount: collectAmount,
          phone_number: collectPhone,
        }),
      });
      setCollection(created);
      if (created.status === "PENDING") pollCollection(created.id, member.id);
    } catch (err) {
      setCollectError(errorDetail(err, tc("error")));
    } finally {
      setCollecting(false);
    }
  }

  async function handleVerifyKyc() {
    if (!member) return;
    setVerifying(true);
    try {
      const updated = await apiFetch<MemberDetail>(`/api/members/${member.id}/verify-kyc/`, {
        method: "POST",
      });
      setMember(updated);
    } finally {
      setVerifying(false);
    }
  }

  async function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !member) return;
    setUploadingPhoto(true);
    try {
      const form = new FormData();
      form.append("photo", file);
      const updated = await apiFetch<MemberDetail>(`/api/members/${member.id}/photo/`, {
        method: "POST",
        body: form,
      });
      setMember(updated);
    } finally {
      setUploadingPhoto(false);
    }
  }

  const relationKindLabel: Record<string, string> = {
    NEXT_OF_KIN: t("kindNextOfKin"),
    NOMINEE: t("kindNominee"),
    BENEFICIARY: t("kindBeneficiary"),
  };
  const categoryLabel: Record<string, string> = {
    ORDINARY: t("categoryOrdinary"),
    ASSOCIATE: t("categoryAssociate"),
    JUNIOR: t("categoryJunior"),
    CORPORATE: t("categoryCorporate"),
  };
  const idTypeLabel: Record<string, string> = {
    NATIONAL_ID: t("idNational"),
    HUDUMA: t("idHuduma"),
    NIDA: t("idNida"),
    PASSPORT: t("idPassport"),
  };

  if (state === "loading") {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (state === "error" || !member) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  const fullName = `${member.first_name} ${member.other_names} ${member.last_name}`.replace(/\s+/g, " ").trim();
  const initials = `${member.first_name[0] ?? ""}${member.last_name[0] ?? ""}`.toUpperCase();

  return (
    <div className="mx-auto max-w-2xl">
      <Link
        href="/members"
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-primary-600 hover:text-primary-800"
      >
        <ArrowLeft size={16} />
        {t("title")}
      </Link>

      <div className="mb-5 flex items-center gap-4">
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          disabled={uploadingPhoto}
          className="group relative flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary-100 text-lg font-semibold text-primary-700"
        >
          {member.photo ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={member.photo} alt="" className="h-full w-full object-cover" />
          ) : (
            initials
          )}
          <span className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 transition-opacity group-hover:opacity-100">
            <Camera size={16} className="text-white" />
          </span>
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handlePhotoChange}
        />
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-xl font-semibold text-primary-900">{fullName}</h1>
          <p className="font-mono text-sm text-primary-500">{member.member_number}</p>
        </div>
        <span
          className={
            "inline-flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium " +
            (member.is_kyc_verified
              ? "bg-primary-100 text-primary-800"
              : "bg-amber-100 text-amber-800")
          }
        >
          {member.is_kyc_verified ? <CheckCircle2 size={13} /> : <Clock size={13} />}
          {member.is_kyc_verified ? t("kycVerified") : t("kycPending")}
        </span>
      </div>

      <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <dl className="divide-y divide-primary-50">
          <Row label={t("category")} value={categoryLabel[member.category] ?? member.category} />
          <Row label={t("idType")} value={idTypeLabel[member.id_type] ?? member.id_type} />
          <Row label={t("idNumber")} value={member.id_number} />
          <Row label={t("phoneNumber")} value={member.phone_number} />
          {member.email && <Row label={t("email")} value={member.email} />}
          {member.physical_address && (
            <Row label={t("physicalAddress")} value={member.physical_address} />
          )}
        </dl>

        {!member.is_kyc_verified && (
          <button
            onClick={handleVerifyKyc}
            disabled={verifying}
            className="mt-5 inline-flex items-center gap-2 rounded-full bg-primary-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            <CheckCircle2 size={16} />
            {t("verifyKyc")}
          </button>
        )}
      </div>

      {hasPermission("members.edit") && (
        <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <KeyRound size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{tp("title")}</h2>
          </div>

          {member.user ? (
            <p className="inline-flex items-center gap-1.5 text-sm text-primary-700">
              <CheckCircle2 size={14} className="text-primary-600" />
              {tp("linked")}
            </p>
          ) : portalInvite ? (
            <div>
              <p className="mb-2 text-sm text-primary-600">{tp("pendingHelp")}</p>
              <button
                type="button"
                onClick={handleCopyPortalLink}
                className="inline-flex items-center gap-1.5 rounded-full border border-primary-200 px-4 py-2 text-xs font-semibold text-primary-700 transition-colors hover:bg-primary-50"
              >
                {linkCopied ? <Check size={13} /> : <Copy size={13} />}
                {linkCopied ? tp("copied") : tp("copyLink")}
              </button>
            </div>
          ) : (
            <div>
              <p className="mb-2 text-sm text-primary-500">{tp("notInvited")}</p>
              <button
                onClick={handleInvitePortalAccess}
                disabled={inviting}
                className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                {tp("invite")}
              </button>
            </div>
          )}
          {inviteError && <p className="mt-2 text-xs text-red-600">{inviteError}</p>}
        </div>
      )}

      <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <div className="mb-4 flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
            <Wallet size={16} strokeWidth={2} />
          </div>
          <h2 className="text-sm font-semibold text-primary-900">{ts("sharesTitle")}</h2>
        </div>

        <Row label={ts("sharesBalance")} value={statement?.shares.balance ?? "-"} />

        <div className="mt-4 flex flex-col gap-2 sm:flex-row">
          <input
            type="number"
            min="0.01"
            step="0.01"
            value={contributeAmount}
            onChange={(e) => setContributeAmount(e.target.value)}
            placeholder={ts("amount")}
            className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
          />
          <button
            onClick={handleContribute}
            disabled={contributing || !contributeAmount}
            className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            {ts("contribute")}
          </button>
        </div>
        {contributeError && <p className="mt-2 text-xs text-red-600">{contributeError}</p>}
      </div>

      <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <div className="mb-4 flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
            <PiggyBank size={16} strokeWidth={2} />
          </div>
          <h2 className="text-sm font-semibold text-primary-900">{ts("savingsTitle")}</h2>
        </div>

        {(!statement || statement.savings_accounts.length === 0) && (
          <p className="text-sm text-primary-500">{ts("noAccounts")}</p>
        )}

        <div className="space-y-4">
          {statement?.savings_accounts.map((account) => (
            <div key={account.id} className="rounded-lg border border-primary-100 p-4">
              <div className="mb-3 flex items-center justify-between">
                <p className="text-sm font-medium text-primary-900">{account.product_name}</p>
                <p className="font-mono text-sm text-primary-900">{account.balance}</p>
              </div>
              <div className="flex flex-col gap-2 sm:flex-row">
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={depositAmounts[account.id] ?? ""}
                  onChange={(e) =>
                    setDepositAmounts((s) => ({ ...s, [account.id]: e.target.value }))
                  }
                  placeholder={ts("amount")}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                />
                <button
                  onClick={() => handleDeposit(account)}
                  disabled={txnBusy[account.id] || !depositAmounts[account.id]}
                  className="rounded-full bg-primary-600 px-4 py-2 text-xs font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
                >
                  {ts("deposit")}
                </button>
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={withdrawAmounts[account.id] ?? ""}
                  onChange={(e) =>
                    setWithdrawAmounts((s) => ({ ...s, [account.id]: e.target.value }))
                  }
                  placeholder={ts("amount")}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                />
                <button
                  onClick={() => handleWithdraw(account)}
                  disabled={txnBusy[account.id] || !withdrawAmounts[account.id]}
                  className="rounded-full border border-primary-200 px-4 py-2 text-xs font-semibold text-primary-700 transition-colors hover:bg-primary-50 disabled:opacity-60"
                >
                  {ts("withdraw")}
                </button>
              </div>
              {txnError[account.id] && (
                <p className="mt-2 text-xs text-red-600">{txnError[account.id]}</p>
              )}
            </div>
          ))}
        </div>

        {products.filter(
          (p) => !statement?.savings_accounts.some((a) => a.product === p.id),
        ).length > 0 && (
          <div className="mt-4 border-t border-primary-50 pt-4">
            <p className="mb-2 text-sm font-medium text-primary-900">{ts("openNewAccount")}</p>
            <div className="flex flex-col gap-2 sm:flex-row">
              <select
                value={newProductId}
                onChange={(e) => setNewProductId(e.target.value)}
                className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
              >
                <option value="">{ts("selectProduct")}</option>
                {products
                  .filter((p) => !statement?.savings_accounts.some((a) => a.product === p.id))
                  .map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
              </select>
              <input
                type="number"
                min="0.01"
                step="0.01"
                value={newAmount}
                onChange={(e) => setNewAmount(e.target.value)}
                placeholder={ts("amount")}
                className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
              />
              <button
                onClick={handleOpenAccount}
                disabled={opening || !newProductId || !newAmount}
                className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                {ts("deposit")}
              </button>
            </div>
            {openError && <p className="mt-2 text-xs text-red-600">{openError}</p>}
          </div>
        )}
      </div>

      <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
        <div className="mb-4 flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
            <Smartphone size={16} strokeWidth={2} />
          </div>
          <h2 className="text-sm font-semibold text-primary-900">{tc("title")}</h2>
        </div>

        <div className="flex flex-col gap-2 sm:flex-row">
          <select
            value={collectProductId}
            onChange={(e) => setCollectProductId(e.target.value)}
            className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
          >
            <option value="">{tc("selectProduct")}</option>
            {products.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
          <input
            type="tel"
            value={collectPhone}
            onChange={(e) => setCollectPhone(e.target.value)}
            placeholder={member.phone_number || tc("phoneNumber")}
            className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
          />
          <input
            type="number"
            min="0.01"
            step="0.01"
            value={collectAmount}
            onChange={(e) => setCollectAmount(e.target.value)}
            placeholder={tc("amount")}
            className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
          />
          <button
            onClick={handleCollect}
            disabled={collecting || !collectProductId || !collectAmount || collection?.status === "PENDING"}
            className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            {tc("submit")}
          </button>
        </div>

        {collectError && <p className="mt-2 text-xs text-red-600">{collectError}</p>}

        {collection && (
          <div data-testid="collect-payment-status" className="mt-3 rounded-lg bg-primary-50 px-4 py-3 text-sm">
            {collection.status === "PENDING" && (
              <span className="flex items-center gap-2 text-primary-700">
                <span className="h-3.5 w-3.5 shrink-0 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
                {tc("pending")}
              </span>
            )}
            {collection.status === "SUCCESS" && <span className="text-primary-700">{tc("success")}</span>}
            {collection.status === "FAILED" && (
              <span className="text-red-600">{tc("failed", { reason: collection.failure_reason })}</span>
            )}
          </div>
        )}
      </div>

      {hasPermission("loans.view") && (
        <div className="mb-5 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <HandCoins size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{tl("title")}</h2>
          </div>

          {loans.length === 0 ? (
            <p className="mb-4 text-sm text-primary-500">{tl("noLoans")}</p>
          ) : (
            <ul className="mb-4 divide-y divide-primary-50">
              {loans.map((loan) => (
                <li key={loan.id} className="flex items-center justify-between gap-3 py-2.5 first:pt-0">
                  <Link href={`/loans/${loan.id}`} className="min-w-0 hover:underline">
                    <p className="truncate text-sm font-medium text-primary-900">{loan.product_name}</p>
                    <p className="font-mono text-xs text-primary-500">{loan.amount_requested}</p>
                  </Link>
                  <LoanStatusBadge status={loan.status} />
                </li>
              ))}
            </ul>
          )}

          {hasPermission("loans.apply_on_behalf") && (
            <div className="border-t border-primary-50 pt-4">
              <p className="mb-2 text-sm font-medium text-primary-900">{ta("title")}</p>
              <div className="mb-2 flex flex-col gap-2 sm:flex-row">
                <select
                  value={applyProductId}
                  onChange={(e) => setApplyProductId(e.target.value)}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                >
                  <option value="">{ta("selectProduct")}</option>
                  {loanProducts.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={applyAmount}
                  onChange={(e) => setApplyAmount(e.target.value)}
                  placeholder={ta("amount")}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                />
                <input
                  type="number"
                  min="1"
                  value={applyTerm}
                  onChange={(e) => setApplyTerm(e.target.value)}
                  placeholder={ta("term")}
                  className="w-32 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                />
              </div>
              <div className="flex flex-col gap-2 sm:flex-row">
                <input
                  type="text"
                  value={applyPurpose}
                  onChange={(e) => setApplyPurpose(e.target.value)}
                  placeholder={ta("purpose")}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500"
                />
                <button
                  onClick={handleApplyForLoan}
                  disabled={applying || !applyProductId || !applyAmount || !applyTerm}
                  className="rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
                >
                  {ta("submit")}
                </button>
              </div>
              {applyError && <p className="mt-2 text-xs text-red-600">{applyError}</p>}
            </div>
          )}
        </div>
      )}

      {member.relations.length > 0 && (
        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <Users size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("relationsSection")}</h2>
          </div>
          <ul className="space-y-3">
            {member.relations.map((r) => (
              <li key={r.id} className="rounded-lg border border-primary-100 p-4 text-sm">
                <p className="font-medium text-primary-900">
                  {r.full_name}{" "}
                  <span className="font-normal text-primary-500">
                    ({relationKindLabel[r.kind] ?? r.kind})
                  </span>
                </p>
                <p className="text-primary-600">{r.relationship}</p>
                {r.phone_number && <p className="text-primary-600">{r.phone_number}</p>}
                {r.benefit_percentage && (
                  <p className="text-primary-600">{r.benefit_percentage}%</p>
                )}
              </li>
            ))}
          </ul>
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
