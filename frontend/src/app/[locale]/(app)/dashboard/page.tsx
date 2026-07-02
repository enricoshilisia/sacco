"use client";

import { useTranslations } from "next-intl";
import { Building2, Mail, MapPin, Phone, User } from "lucide-react";
import { Link } from "@/i18n/navigation";
import { useTenantProfile } from "@/lib/TenantProfileContext";

export default function DashboardPage() {
  const t = useTranslations("Dashboard");
  const { profile } = useTenantProfile();
  if (!profile) return null;

  const { tenant, user, memberships } = profile;
  const fullName = `${user.first_name} ${user.last_name}`.trim();
  const primaryMembership = memberships[0];

  return (
    <div>
      <p className="mb-6 text-xl font-semibold text-primary-900">
        {t("welcome", { name: fullName || user.phone_number })}
      </p>

      <Link
        href="/members"
        className="mb-6 inline-flex items-center gap-2 rounded-full bg-primary-600 px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700"
      >
        {t("viewMembers")}
      </Link>

      <div className="grid gap-5 lg:grid-cols-2">
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
