"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Bell, Smartphone } from "lucide-react";
import { apiFetch, ApiError } from "@/lib/api";

type PaymentCollection = {
  id: string;
  member_name: string;
  product_name: string;
  provider: string;
  phone_number: string;
  amount: string;
  status: "PENDING" | "SUCCESS" | "FAILED" | "CANCELLED";
  provider_reference: string;
  provider_receipt: string;
  failure_reason: string;
  created_at: string;
};

type NotificationLog = {
  id: string;
  member_name: string | null;
  channel: string;
  event_type: string;
  recipient: string;
  message: string;
  provider: string;
  status: "PENDING" | "SENT" | "FAILED";
  error: string;
  created_at: string;
};

const TABS = [
  { key: "collections", icon: Smartphone },
  { key: "notifications", icon: Bell },
] as const;

type TabKey = (typeof TABS)[number]["key"];

const STATUS_STYLES: Record<string, string> = {
  PENDING: "bg-amber-100 text-amber-800",
  SENT: "bg-primary-100 text-primary-800",
  SUCCESS: "bg-primary-100 text-primary-800",
  FAILED: "bg-red-50 text-red-700",
  CANCELLED: "bg-primary-50 text-primary-500",
};

export default function PaymentsPage() {
  const t = useTranslations("Payments");
  const [tab, setTab] = useState<TabKey>("collections");

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

      {tab === "collections" && <CollectionsTab />}
      {tab === "notifications" && <NotificationsTab />}
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const t = useTranslations("Payments");
  const labelKey = `status${status.charAt(0)}${status.slice(1).toLowerCase()}`;
  return (
    <span
      className={
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium " +
        (STATUS_STYLES[status] ?? "bg-primary-50 text-primary-600")
      }
    >
      {t.has(labelKey) ? t(labelKey) : status}
    </span>
  );
}

function CollectionsTab() {
  const t = useTranslations("Payments");
  const [collections, setCollections] = useState<PaymentCollection[]>([]);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");

  useEffect(() => {
    apiFetch<{ results: PaymentCollection[] }>("/api/payments/collections/")
      .then((data) => {
        setCollections(data.results);
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

  if (state === "forbidden") {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  if (collections.length === 0) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-primary-500">{t("noCollections")}</p>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-primary-100/80">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[760px] text-left text-sm">
          <thead>
            <tr className="border-b border-primary-100 bg-primary-50/50 text-xs font-medium uppercase tracking-wide text-primary-500">
              <th className="px-5 py-3">{t("member")}</th>
              <th className="px-5 py-3">{t("product")}</th>
              <th className="px-5 py-3">{t("provider")}</th>
              <th className="px-5 py-3">{t("phoneNumber")}</th>
              <th className="px-5 py-3 text-right">{t("amount")}</th>
              <th className="px-5 py-3">{t("status")}</th>
              <th className="px-5 py-3">{t("receipt")}</th>
            </tr>
          </thead>
          <tbody>
            {collections.map((c) => (
              <tr key={c.id} className="border-b border-primary-50 last:border-0">
                <td className="px-5 py-3.5 font-medium text-primary-900">{c.member_name}</td>
                <td className="px-5 py-3.5 text-primary-600">{c.product_name}</td>
                <td className="px-5 py-3.5 text-primary-600">{c.provider}</td>
                <td className="px-5 py-3.5 font-mono text-primary-700">{c.phone_number}</td>
                <td className="px-5 py-3.5 text-right font-mono text-primary-900">{c.amount}</td>
                <td className="px-5 py-3.5">
                  <StatusBadge status={c.status} />
                  {c.status === "FAILED" && c.failure_reason && (
                    <p className="mt-1 text-xs text-red-600">{c.failure_reason}</p>
                  )}
                </td>
                <td className="px-5 py-3.5 font-mono text-xs text-primary-500">
                  {c.provider_receipt || c.provider_reference}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function NotificationsTab() {
  const t = useTranslations("Payments");
  const [logs, setLogs] = useState<NotificationLog[]>([]);
  const [state, setState] = useState<"loading" | "ready" | "forbidden">("loading");

  useEffect(() => {
    apiFetch<{ results: NotificationLog[] }>("/api/notifications/log/")
      .then((data) => {
        setLogs(data.results);
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

  if (state === "forbidden") {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-red-600">{t("forbidden")}</p>
      </div>
    );
  }

  if (logs.length === 0) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow-sm ring-1 ring-primary-100/80">
        <p className="text-sm text-primary-500">{t("noNotifications")}</p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {logs.map((log) => (
        <div key={log.id} className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-primary-100/80">
          <div className="mb-2 flex items-center justify-between gap-3">
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-primary-900">
                {log.member_name ?? log.recipient} <span className="text-primary-400">· {log.event_type}</span>
              </p>
              <p className="font-mono text-xs text-primary-500">{log.recipient}</p>
            </div>
            <StatusBadge status={log.status} />
          </div>
          <p className="text-sm text-primary-700">{log.message}</p>
          {log.status === "FAILED" && log.error && <p className="mt-1 text-xs text-red-600">{log.error}</p>}
        </div>
      ))}
    </div>
  );
}
