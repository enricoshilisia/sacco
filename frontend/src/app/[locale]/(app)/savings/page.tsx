"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Check, Clock, PiggyBank, Wallet } from "lucide-react";
import { apiFetch, ApiError } from "@/lib/api";
import { useTenantProfile } from "@/lib/TenantProfileContext";

type ShareContribution = { id: string; amount: string; transaction_date: string };
type SavingsTransaction = { id: string; amount: string; transaction_date: string; transaction_type: string };

type MyStatement = {
  shares: { balance: string; contributions: ShareContribution[] };
  savings_accounts: {
    id: string;
    product: string;
    product_name: string;
    account_number: string;
    balance: string;
    transactions: SavingsTransaction[];
  }[];
};

type SavingsProductOption = { id: string; name: string };

function errorDetail(err: unknown, fallback: string) {
  if (err instanceof ApiError && err.body && typeof err.body === "object" && "detail" in err.body) {
    const detail = (err.body as { detail?: string }).detail;
    if (detail) return detail;
  }
  return fallback;
}

export default function SavingsPage() {
  const t = useTranslations("Savings");
  const { myMemberId } = useTenantProfile();

  const [statement, setStatement] = useState<MyStatement | null | undefined>(undefined);
  const [products, setProducts] = useState<SavingsProductOption[]>([]);

  const [contributeAmount, setContributeAmount] = useState("");
  const [contributePhone, setContributePhone] = useState("");
  const [contributing, setContributing] = useState(false);
  const [contributeError, setContributeError] = useState("");
  const [contributeSent, setContributeSent] = useState(false);

  const [depositProductId, setDepositProductId] = useState("");
  const [depositAmount, setDepositAmount] = useState("");
  const [depositPhone, setDepositPhone] = useState("");
  const [depositing, setDepositing] = useState(false);
  const [depositError, setDepositError] = useState("");
  const [depositSent, setDepositSent] = useState(false);

  function loadStatement() {
    apiFetch<MyStatement>("/api/savings/me/statement/")
      .then(setStatement)
      .catch(() => setStatement(null));
  }

  useEffect(() => {
    if (myMemberId) {
      loadStatement();
      apiFetch<{ results: SavingsProductOption[] }>("/api/savings/products/")
        .then((data) => setProducts(data.results))
        .catch(() => {});
    }
  }, [myMemberId]);

  async function handleContribute() {
    if (!contributeAmount || !contributePhone) return;
    setContributing(true);
    setContributeError("");
    setContributeSent(false);
    try {
      await apiFetch("/api/payments/me/collect/", {
        method: "POST",
        body: JSON.stringify({
          purpose: "SHARE_CONTRIBUTION",
          amount: contributeAmount,
          phone_number: contributePhone,
        }),
      });
      setContributeAmount("");
      setContributeSent(true);
    } catch (err) {
      setContributeError(errorDetail(err, t("error")));
    } finally {
      setContributing(false);
    }
  }

  async function handleDeposit() {
    if (!depositProductId || !depositAmount || !depositPhone) return;
    setDepositing(true);
    setDepositError("");
    setDepositSent(false);
    try {
      await apiFetch("/api/payments/me/collect/", {
        method: "POST",
        body: JSON.stringify({
          purpose: "SAVINGS_DEPOSIT",
          product: depositProductId,
          amount: depositAmount,
          phone_number: depositPhone,
        }),
      });
      setDepositAmount("");
      setDepositSent(true);
    } catch (err) {
      setDepositError(errorDetail(err, t("error")));
    } finally {
      setDepositing(false);
    }
  }

  if (myMemberId === undefined) {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (!myMemberId) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  if (statement === undefined) {
    return (
      <div className="flex justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (statement === null) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  return (
    <div>
      <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("title")}</h1>

      <div className="grid gap-5 lg:grid-cols-2">
        <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <Wallet size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("shares")}</h2>
          </div>
          <p className="mb-4 text-2xl font-semibold text-primary-900">{statement.shares.balance}</p>

          <div className="border-t border-primary-50 pt-4">
            <p className="mb-2 text-sm font-medium text-primary-900">{t("contributeShares")}</p>
            <p className="mb-3 text-xs text-primary-500">{t("mobileMoneyHelp")}</p>
            <div className="flex flex-col gap-2">
              <div className="flex gap-2">
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={contributeAmount}
                  onChange={(e) => setContributeAmount(e.target.value)}
                  placeholder={t("amount")}
                  disabled={contributing}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                />
                <input
                  type="tel"
                  value={contributePhone}
                  onChange={(e) => setContributePhone(e.target.value)}
                  placeholder={t("phoneNumber")}
                  disabled={contributing}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                />
              </div>
              <button
                onClick={handleContribute}
                disabled={contributing || !contributeAmount || !contributePhone}
                className="inline-flex items-center justify-center gap-2 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                <PiggyBank size={16} />
                {t("contributeSubmit")}
              </button>
            </div>
            {contributeError && <p className="mt-2 text-xs text-red-600">{contributeError}</p>}
            {contributeSent && (
              <p className="mt-2 flex items-center gap-1.5 text-xs text-primary-600">
                <Clock size={13} />
                {t("stkSent")}
              </p>
            )}
          </div>
        </section>

        <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-4 flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <PiggyBank size={16} strokeWidth={2} />
            </div>
            <h2 className="text-sm font-semibold text-primary-900">{t("savingsAccounts")}</h2>
          </div>

          {statement.savings_accounts.length === 0 ? (
            <p className="mb-4 text-sm text-primary-500">{t("noSavingsAccounts")}</p>
          ) : (
            <ul className="mb-4 divide-y divide-primary-50">
              {statement.savings_accounts.map((acc) => (
                <li key={acc.id} className="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0">
                  <span className="text-sm text-primary-700">{acc.product_name}</span>
                  <span className="font-mono text-sm font-medium text-primary-900">{acc.balance}</span>
                </li>
              ))}
            </ul>
          )}

          <div className="border-t border-primary-50 pt-4">
            <p className="mb-2 text-sm font-medium text-primary-900">{t("depositSavings")}</p>
            <p className="mb-3 text-xs text-primary-500">{t("mobileMoneyHelp")}</p>
            <div className="flex flex-col gap-2">
              <select
                value={depositProductId}
                onChange={(e) => setDepositProductId(e.target.value)}
                disabled={depositing}
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
                  type="number"
                  min="0.01"
                  step="0.01"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                  placeholder={t("amount")}
                  disabled={depositing}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                />
                <input
                  type="tel"
                  value={depositPhone}
                  onChange={(e) => setDepositPhone(e.target.value)}
                  placeholder={t("phoneNumber")}
                  disabled={depositing}
                  className="flex-1 rounded-lg border border-primary-200 bg-white px-3 py-2 text-sm text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500 disabled:opacity-60"
                />
              </div>
              <button
                onClick={handleDeposit}
                disabled={depositing || !depositProductId || !depositAmount || !depositPhone}
                className="inline-flex items-center justify-center gap-2 rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-60"
              >
                <Check size={16} />
                {t("depositSubmit")}
              </button>
            </div>
            {depositError && <p className="mt-2 text-xs text-red-600">{depositError}</p>}
            {depositSent && (
              <p className="mt-2 flex items-center gap-1.5 text-xs text-primary-600">
                <Clock size={13} />
                {t("stkSent")}
              </p>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
