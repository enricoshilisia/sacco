"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Building2, LayoutDashboard, LogOut, Menu, Settings, Users, X } from "lucide-react";
import { Link, usePathname } from "@/i18n/navigation";
import { useTenantProfile } from "@/lib/TenantProfileContext";
import LanguageSwitcher from "@/components/LanguageSwitcher";

type NavItem = {
  href: "/dashboard" | "/members" | "/settings";
  label: string;
  icon: typeof LayoutDashboard;
};

export default function AppShell({ children }: { children: React.ReactNode }) {
  const t = useTranslations("Nav");
  const pathname = usePathname();
  const { profile, status, logout } = useTenantProfile();
  const [mobileOpen, setMobileOpen] = useState(false);

  const navItems: NavItem[] = [
    { href: "/dashboard", label: t("dashboard"), icon: LayoutDashboard },
    { href: "/members", label: t("members"), icon: Users },
    { href: "/settings", label: t("settings"), icon: Settings },
  ];

  const saccoName = profile?.tenant.name ?? "SACCO";
  const userName =
    profile && `${profile.user.first_name} ${profile.user.last_name}`.trim();
  const roleName = profile?.memberships[0]?.role_name;

  function isActive(href: string) {
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  const sidebarContent = (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 px-5 py-5">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-primary-600 text-white">
          {profile?.tenant.logo ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={profile.tenant.logo} alt="" className="h-full w-full object-cover" />
          ) : (
            <Building2 size={18} />
          )}
        </div>
        <span className="truncate text-sm font-semibold text-primary-900">{saccoName}</span>
      </div>

      <nav className="flex-1 space-y-1 px-3">
        {navItems.map(({ href, label, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            data-testid={`nav-${href.slice(1)}`}
            onClick={() => setMobileOpen(false)}
            className={
              "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors " +
              (isActive(href)
                ? "bg-primary-50 text-primary-700"
                : "text-primary-600 hover:bg-primary-50 hover:text-primary-800")
            }
          >
            <Icon size={18} strokeWidth={2} />
            {label}
          </Link>
        ))}
      </nav>

      <div className="border-t border-primary-100 px-3 py-4">
        <div className="mb-3 px-3">
          <LanguageSwitcher />
        </div>
        {userName && (
          <div className="mb-2 flex items-center gap-3 rounded-lg px-3 py-2">
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary-100 text-xs font-semibold text-primary-700">
              {userName
                .split(" ")
                .map((p) => p[0])
                .join("")
                .slice(0, 2)
                .toUpperCase()}
            </div>
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-primary-900">{userName}</p>
              {roleName && <p className="truncate text-xs text-primary-500">{roleName}</p>}
            </div>
          </div>
        )}
        <button
          onClick={logout}
          className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-primary-600 transition-colors hover:bg-primary-50 hover:text-primary-800"
        >
          <LogOut size={18} strokeWidth={2} />
          {t("logout")}
        </button>
      </div>
    </div>
  );

  if (status === "loading") {
    return (
      <div className="flex min-h-full flex-1 items-center justify-center bg-primary-50">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (status === "expired") {
    return (
      <div className="flex min-h-full flex-1 flex-col items-center justify-center gap-4 bg-primary-50 px-6 text-center">
        <p className="text-sm text-primary-700">Your session has expired.</p>
        <Link
          href="/login"
          className="rounded-full bg-primary-600 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-primary-700"
        >
          {t("logout")}
        </Link>
      </div>
    );
  }

  return (
    <div className="flex min-h-full bg-primary-50">
      {/* Desktop sidebar */}
      <aside className="hidden w-64 shrink-0 border-r border-primary-100 bg-white md:block">
        {sidebarContent}
      </aside>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-40 md:hidden">
          <div
            className="absolute inset-0 bg-black/30"
            onClick={() => setMobileOpen(false)}
            aria-hidden="true"
          />
          <aside className="absolute inset-y-0 left-0 w-72 bg-white shadow-xl">
            <button
              onClick={() => setMobileOpen(false)}
              className="absolute right-3 top-4 rounded-lg p-2 text-primary-500 hover:bg-primary-50"
              aria-label="Close menu"
            >
              <X size={20} />
            </button>
            {sidebarContent}
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile top bar */}
        <header className="flex items-center gap-3 border-b border-primary-100 bg-white px-4 py-3 md:hidden">
          <button
            onClick={() => setMobileOpen(true)}
            className="rounded-lg p-2 text-primary-600 hover:bg-primary-50"
            aria-label="Open menu"
          >
            <Menu size={20} />
          </button>
          <span className="truncate text-sm font-semibold text-primary-900">{saccoName}</span>
        </header>

        <main className="flex-1 px-4 py-6 sm:px-6 lg:px-8">{children}</main>
      </div>
    </div>
  );
}
