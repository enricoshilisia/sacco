"use client";

import { useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Building2, LayoutDashboard, LogOut, Scale, Settings, Users, X } from "lucide-react";
import { Link, usePathname } from "@/i18n/navigation";
import { useTenantProfile } from "@/lib/TenantProfileContext";
import LanguageSwitcher from "@/components/LanguageSwitcher";

/** Minimum upward/downward drag distance (px) before a touch counts as a swipe. */
const SWIPE_THRESHOLD = 28;

type NavItem = {
  href: "/dashboard" | "/members" | "/accounting" | "/settings";
  label: string;
  icon: typeof LayoutDashboard;
  /** Omit for items everyone can see (e.g. Dashboard). Otherwise the item
   * only renders if the user holds at least one of these permission codes -
   * accesscontrol is the single source of truth for both this and the
   * page-level 403 each of these routes also enforces. */
  permissions?: string[];
};

export default function AppShell({ children }: { children: React.ReactNode }) {
  const t = useTranslations("Nav");
  const pathname = usePathname();
  const { profile, status, logout, hasAnyPermission } = useTenantProfile();
  const [sheetOpen, setSheetOpen] = useState(false);
  const touchStartY = useRef<number | null>(null);

  const allNavItems: NavItem[] = [
    { href: "/dashboard", label: t("dashboard"), icon: LayoutDashboard },
    { href: "/members", label: t("members"), icon: Users, permissions: ["members.view"] },
    {
      href: "/accounting",
      label: t("accounting"),
      icon: Scale,
      permissions: ["accounting.view_trial_balance", "accounting.view_ledger"],
    },
    {
      href: "/settings",
      label: t("settings"),
      icon: Settings,
      permissions: ["configuration.view", "accesscontrol.assign_roles"],
    },
  ];
  const navItems = allNavItems.filter((item) => !item.permissions || hasAnyPermission(item.permissions));

  const saccoName = profile?.tenant.name ?? "SACCO";
  const userName =
    profile && `${profile.user.first_name} ${profile.user.last_name}`.trim();
  const roleName = profile?.memberships[0]?.role_name;
  const initials = userName
    ? userName
        .split(" ")
        .map((p) => p[0])
        .join("")
        .slice(0, 2)
        .toUpperCase()
    : "";

  function isActive(href: string) {
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  const brand = (
    <div className="flex min-w-0 items-center gap-2.5">
      <div className="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-primary-600 text-white">
        {profile?.tenant.logo ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={profile.tenant.logo} alt="" className="h-full w-full object-cover" />
        ) : (
          <Building2 size={18} />
        )}
      </div>
      <span className="min-w-0 truncate text-sm font-semibold text-primary-900">{saccoName}</span>
    </div>
  );

  // Desktop sidebar: a vertical list of rows.
  const navLinks = (
    <nav className="flex-1 space-y-1 px-3 py-4">
      {navItems.map(({ href, label, icon: Icon }) => (
        <Link
          key={href}
          href={href}
          data-testid={`nav-${href.slice(1)}`}
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
  );

  // Mobile bottom sheet: an app-launcher style grid of icon cards.
  const navCards = (
    <div className="grid grid-cols-3 gap-3 px-5 pb-6 pt-1">
      {navItems.map(({ href, label, icon: Icon }) => {
        const active = isActive(href);
        return (
          <Link
            key={href}
            href={href}
            data-testid={`nav-${href.slice(1)}`}
            onClick={() => setSheetOpen(false)}
            className={
              "flex flex-col items-center gap-2 rounded-2xl p-4 text-center transition-colors " +
              (active ? "bg-primary-50 ring-1 ring-primary-200" : "bg-primary-50/40 active:bg-primary-50")
            }
          >
            <div
              className={
                "flex h-12 w-12 items-center justify-center rounded-2xl " +
                (active ? "bg-primary-600 text-white" : "bg-white text-primary-600 ring-1 ring-primary-100")
              }
            >
              <Icon size={22} strokeWidth={2} />
            </div>
            <span className={"text-xs font-medium " + (active ? "text-primary-800" : "text-primary-700")}>
              {label}
            </span>
          </Link>
        );
      })}
    </div>
  );

  const activeItem = navItems.find((item) => isActive(item.href)) ?? navItems[0];

  const profileCluster = (
    <div className="flex shrink-0 items-center gap-3 sm:gap-4">
      <LanguageSwitcher />
      {userName && (
        <div className="hidden items-center gap-2.5 sm:flex">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary-100 text-xs font-semibold text-primary-700">
            {initials}
          </div>
          <div className="min-w-0">
            <p className="max-w-[10rem] truncate text-sm font-medium text-primary-900">{userName}</p>
            {roleName && <p className="truncate text-xs text-primary-500">{roleName}</p>}
          </div>
        </div>
      )}
      {userName && (
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary-100 text-xs font-semibold text-primary-700 sm:hidden">
          {initials}
        </div>
      )}
      <button
        onClick={logout}
        aria-label={t("logout")}
        title={t("logout")}
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-primary-600 transition-colors hover:bg-primary-50 hover:text-primary-800"
      >
        <LogOut size={18} strokeWidth={2} />
      </button>
    </div>
  );

  if (status === "loading") {
    return (
      <div className="flex h-full flex-1 items-center justify-center bg-primary-50">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary-300 border-t-primary-600" />
      </div>
    );
  }

  if (status === "expired") {
    return (
      <div className="flex h-full flex-1 flex-col items-center justify-center gap-4 bg-primary-50 px-6 text-center">
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
    <div className="flex h-full flex-col bg-primary-50">
      {/* Static top bar - spans the full width; its left zone lines up
          with the sidebar's width/border below so the two read as one
          connected frame rather than two floating panels. */}
      <header className="flex h-16 shrink-0 items-stretch border-b border-primary-100 bg-white">
        <div className="hidden w-64 shrink-0 items-center border-r border-primary-100 px-5 md:flex">
          {brand}
        </div>
        <div className="flex min-w-0 flex-1 items-center justify-between gap-3 px-4 sm:px-6">
          <div className="min-w-0">{brand}</div>
          {profileCluster}
        </div>
      </header>

      <div className="flex flex-1 overflow-hidden">
        {/* Static desktop sidebar */}
        <aside className="hidden w-64 shrink-0 flex-col overflow-y-auto border-r border-primary-100 bg-white md:flex">
          {navLinks}
        </aside>

        {/* The only scrollable region - bars above/beside it stay put. Bottom
            padding on mobile clears the swipe-up handle docked over it. */}
        <main className="flex-1 overflow-y-auto px-4 pb-24 pt-6 sm:px-6 sm:pb-6 lg:px-8">{children}</main>
      </div>

      {/* Mobile nav: no hamburger - a docked handle you swipe up (or tap)
          to open an app-style bottom sheet of nav cards. */}
      <div
        data-testid="mobile-nav-handle"
        className="fixed inset-x-0 bottom-0 z-40 flex touch-none flex-col items-center border-t border-primary-100 bg-white/95 pb-[env(safe-area-inset-bottom)] pt-2 shadow-[0_-4px_12px_rgba(0,0,0,0.04)] backdrop-blur md:hidden"
        onTouchStart={(e) => {
          touchStartY.current = e.touches[0].clientY;
        }}
        onTouchMove={(e) => {
          if (touchStartY.current === null) return;
          if (touchStartY.current - e.touches[0].clientY > SWIPE_THRESHOLD) {
            setSheetOpen(true);
            touchStartY.current = null;
          }
        }}
        onTouchEnd={() => {
          touchStartY.current = null;
        }}
        onClick={() => setSheetOpen(true)}
        role="button"
        aria-label="Open menu"
      >
        <span className="mb-2 h-1.5 w-10 shrink-0 rounded-full bg-primary-200" />
        {activeItem && (
          <span className="mb-2 flex items-center gap-2 text-xs font-medium text-primary-600">
            <activeItem.icon size={14} strokeWidth={2} />
            {activeItem.label}
          </span>
        )}
      </div>

      {/* Bottom sheet */}
      <div
        className={
          "fixed inset-0 z-50 md:hidden " + (sheetOpen ? "" : "pointer-events-none")
        }
        aria-hidden={!sheetOpen}
      >
        <div
          className={
            "absolute inset-0 bg-black/30 transition-opacity duration-300 " +
            (sheetOpen ? "opacity-100" : "opacity-0")
          }
          onClick={() => setSheetOpen(false)}
        />
        <div
          data-testid="bottom-sheet"
          className={
            "absolute inset-x-0 bottom-0 rounded-t-3xl bg-white pb-[env(safe-area-inset-bottom)] shadow-2xl transition-transform duration-300 ease-out " +
            (sheetOpen ? "translate-y-0" : "translate-y-full")
          }
          onTouchStart={(e) => {
            touchStartY.current = e.touches[0].clientY;
          }}
          onTouchMove={(e) => {
            if (touchStartY.current === null) return;
            if (e.touches[0].clientY - touchStartY.current > SWIPE_THRESHOLD) {
              setSheetOpen(false);
              touchStartY.current = null;
            }
          }}
          onTouchEnd={() => {
            touchStartY.current = null;
          }}
        >
          <div className="relative flex items-center justify-center py-3">
            <span className="h-1.5 w-10 rounded-full bg-primary-200" />
            <button
              onClick={() => setSheetOpen(false)}
              className="absolute right-3 top-2 rounded-lg p-2 text-primary-400 hover:bg-primary-50"
              aria-label="Close menu"
            >
              <X size={18} />
            </button>
          </div>
          {navCards}
        </div>
      </div>
    </div>
  );
}
