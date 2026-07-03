"use client";

import Image from "next/image";
import { useTranslations } from "next-intl";
import {
  ArrowRight,
  HandCoins,
  Landmark,
  LineChart,
  ScrollText,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Wallet,
} from "lucide-react";
import { Link } from "@/i18n/navigation";
import { useIsLoggedIn } from "@/lib/useIsLoggedIn";
import LanguageSwitcher from "@/components/LanguageSwitcher";

export default function Home() {
  const t = useTranslations("Home");
  const tNav = useTranslations("Nav");
  const loggedIn = useIsLoggedIn();

  return (
    <div className="flex min-h-full flex-col bg-primary-50">
      <header className="sticky top-0 z-20 border-b border-primary-100/80 bg-primary-50/80 backdrop-blur-sm">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6">
          <div className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-600 text-sm font-bold text-white">
              S
            </div>
            <span className="text-base font-semibold text-primary-900">{t("title")}</span>
          </div>

          <div className="flex items-center gap-3 sm:gap-5">
            <a
              href="#features"
              className="hidden text-sm font-medium text-primary-700 hover:text-primary-900 sm:inline"
            >
              {t("navFeatures")}
            </a>
            <div className="hidden sm:block">
              <LanguageSwitcher />
            </div>
            {loggedIn ? (
              <Link
                href="/dashboard"
                className="whitespace-nowrap rounded-full bg-primary-600 px-3.5 py-2 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 sm:px-4"
              >
                {tNav("dashboard")}
              </Link>
            ) : (
              <>
                <Link
                  href="/login"
                  className="hidden text-sm font-medium text-primary-700 hover:text-primary-900 sm:inline"
                >
                  {t("login")}
                </Link>
                <Link
                  href="/signup-sacco"
                  className="whitespace-nowrap rounded-full bg-primary-600 px-3.5 py-2 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 sm:px-4"
                >
                  <span className="sm:hidden">{t("startSaccoShort")}</span>
                  <span className="hidden sm:inline">{t("startSacco")}</span>
                </Link>
              </>
            )}
          </div>
        </div>
      </header>

      <main className="flex-1">
        {/* Hero */}
        <section className="relative overflow-hidden px-4 pb-20 pt-14 sm:px-6 sm:pt-20">
          <div
            aria-hidden
            className="absolute -top-24 right-[-10%] h-96 w-96 rounded-full bg-primary-200/50 blur-3xl sm:right-0"
          />
          <div
            aria-hidden
            className="absolute -bottom-32 left-[-10%] h-80 w-80 rounded-full bg-primary-300/30 blur-3xl"
          />

          <div className="relative mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-2 lg:gap-8">
            <div>
              <span className="inline-flex items-center gap-1.5 rounded-full bg-white px-3 py-1.5 text-xs font-semibold text-primary-700 shadow-sm ring-1 ring-primary-100">
                <Sparkles size={13} strokeWidth={2.5} />
                {t("eyebrow")}
              </span>

              <h1 className="mt-5 text-4xl font-semibold leading-tight tracking-tight text-primary-950 sm:text-5xl">
                {t("heroTitle")}
              </h1>
              <p className="mt-5 max-w-lg text-base leading-7 text-primary-700 sm:text-lg">
                {t("heroSubtitle")}
              </p>

              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <Link
                  href="/signup-sacco"
                  className="inline-flex items-center justify-center gap-2 rounded-full bg-primary-600 px-6 py-3.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 active:bg-primary-800"
                >
                  {t("startSacco")}
                  <ArrowRight size={16} />
                </Link>
                <Link
                  href="/login"
                  className="inline-flex items-center justify-center rounded-full border border-primary-200 bg-white px-6 py-3.5 text-sm font-semibold text-primary-800 transition-colors hover:bg-primary-50"
                >
                  {t("login")}
                </Link>
              </div>
            </div>

            <div className="relative mx-auto w-full max-w-md lg:max-w-none">
              <div className="relative aspect-[4/3] -rotate-2 overflow-hidden rounded-3xl shadow-2xl ring-1 ring-primary-900/10 transition-transform duration-500 hover:rotate-0">
                <Image
                  src="/marketing/laptop-dashboard.jpg"
                  alt={t("heroImageAlt")}
                  fill
                  priority
                  sizes="(min-width: 1024px) 560px, 90vw"
                  className="object-cover"
                />
              </div>
            </div>
          </div>
        </section>

        {/* Feature intro */}
        <section id="features" className="px-4 pt-4 sm:px-6">
          <div className="mx-auto max-w-6xl text-center">
            <span className="text-xs font-semibold uppercase tracking-wider text-primary-500">
              {t("sectionEyebrow")}
            </span>
            <h2 className="mx-auto mt-3 max-w-2xl text-2xl font-semibold tracking-tight text-primary-950 sm:text-3xl">
              {t("sectionTitle")}
            </h2>
          </div>
        </section>

        {/* Feature rows */}
        <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
          <div className="flex flex-col gap-20">
            <FeatureRow
              icon={Wallet}
              image="/marketing/savings-jar.jpg"
              imageAlt={t("savingsImageAlt")}
              imagePosition="object-center"
              title={t("savingsTitle")}
              body={t("savingsBody")}
            />
            <FeatureRow
              icon={HandCoins}
              image="/marketing/coin-plant-sprout.jpg"
              imageAlt={t("loansImageAlt")}
              imagePosition="object-left"
              title={t("loansTitle")}
              body={t("loansBody")}
              reverse
            />
            <FeatureRow
              icon={ScrollText}
              image="/marketing/calculator-ledger.jpg"
              imageAlt={t("accountingImageAlt")}
              imagePosition="object-center"
              title={t("accountingTitle")}
              body={t("accountingBody")}
            />
            <FeatureRow
              icon={LineChart}
              image="/marketing/tablet-charts.jpg"
              imageAlt={t("reportsImageAlt")}
              imagePosition="object-center"
              title={t("reportsTitle")}
              body={t("reportsBody")}
              reverse
            />
          </div>
        </section>

        {/* Compliance band */}
        <section className="border-y border-primary-100 bg-white">
          <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 py-16 sm:px-6 lg:grid-cols-2 lg:gap-16">
            <div className="relative aspect-[16/10] overflow-hidden rounded-3xl shadow-lg ring-1 ring-primary-900/5">
              <Image
                src="/marketing/tax-forms.jpg"
                alt={t("complianceImageAlt")}
                fill
                sizes="(min-width: 1024px) 560px, 90vw"
                className="object-cover"
              />
            </div>
            <div>
              <span className="inline-flex items-center gap-1.5 rounded-full bg-primary-50 px-3 py-1.5 text-xs font-semibold text-primary-700">
                <ShieldCheck size={13} strokeWidth={2.5} />
                {t("complianceEyebrow")}
              </span>
              <h2 className="mt-4 text-2xl font-semibold tracking-tight text-primary-950 sm:text-3xl">
                {t("complianceTitle")}
              </h2>
              <p className="mt-4 max-w-md text-base leading-7 text-primary-700">
                {t("complianceBody")}
              </p>
            </div>
          </div>
        </section>

        {/* Anywhere band */}
        <section>
          <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 py-16 sm:px-6 lg:grid-cols-2 lg:gap-16">
            <div className="lg:order-2">
              <div className="relative aspect-[16/10] overflow-hidden rounded-3xl shadow-lg ring-1 ring-primary-900/5">
                <Image
                  src="/marketing/desk-charts-phone.jpg"
                  alt={t("anywhereImageAlt")}
                  fill
                  sizes="(min-width: 1024px) 560px, 90vw"
                  className="object-cover"
                />
              </div>
            </div>
            <div className="lg:order-1">
              <span className="inline-flex items-center gap-1.5 rounded-full bg-primary-50 px-3 py-1.5 text-xs font-semibold text-primary-700">
                <Smartphone size={13} strokeWidth={2.5} />
                {t("anywhereEyebrow")}
              </span>
              <h2 className="mt-4 text-2xl font-semibold tracking-tight text-primary-950 sm:text-3xl">
                {t("anywhereTitle")}
              </h2>
              <p className="mt-4 max-w-md text-base leading-7 text-primary-700">
                {t("anywhereBody")}
              </p>
            </div>
          </div>
        </section>

        {/* Craft band */}
        <section className="border-y border-primary-100 bg-white">
          <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 py-16 sm:px-6 lg:grid-cols-2 lg:gap-16">
            <div className="relative aspect-[16/10] overflow-hidden rounded-3xl shadow-lg ring-1 ring-primary-900/5">
              <Image
                src="/marketing/ux-wireframe-wall.jpg"
                alt={t("craftImageAlt")}
                fill
                sizes="(min-width: 1024px) 560px, 90vw"
                className="object-cover object-left"
              />
            </div>
            <div>
              <span className="inline-flex items-center gap-1.5 rounded-full bg-primary-50 px-3 py-1.5 text-xs font-semibold text-primary-700">
                <Landmark size={13} strokeWidth={2.5} />
                {t("craftEyebrow")}
              </span>
              <h2 className="mt-4 text-2xl font-semibold tracking-tight text-primary-950 sm:text-3xl">
                {t("craftTitle")}
              </h2>
              <p className="mt-4 max-w-md text-base leading-7 text-primary-700">
                {t("craftBody")}
              </p>
            </div>
          </div>
        </section>

        {/* Final CTA */}
        <section className="relative overflow-hidden">
          <div className="absolute inset-0">
            <Image
              src="/marketing/coin-stacks.jpg"
              alt={t("ctaImageAlt")}
              fill
              sizes="100vw"
              className="object-cover object-[50%_65%]"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-primary-950/90 via-primary-950/70 to-primary-950/40" />
          </div>

          <div className="relative mx-auto max-w-3xl px-4 py-24 text-center sm:px-6">
            <h2 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
              {t("ctaTitle")}
            </h2>
            <p className="mt-4 text-base leading-7 text-primary-100">{t("ctaSubtitle")}</p>
            <Link
              href="/signup-sacco"
              className="mt-8 inline-flex items-center justify-center gap-2 rounded-full bg-white px-7 py-3.5 text-sm font-semibold text-primary-900 shadow-sm transition-colors hover:bg-primary-50"
            >
              {t("startSacco")}
              <ArrowRight size={16} />
            </Link>
          </div>
        </section>
      </main>

      <footer className="border-t border-primary-100 bg-white">
        <div className="mx-auto flex max-w-6xl flex-col items-center gap-4 px-4 py-10 text-center sm:flex-row sm:justify-between sm:px-6 sm:text-left">
          <div>
            <div className="flex items-center justify-center gap-2 sm:justify-start">
              <div className="flex h-7 w-7 items-center justify-center rounded-md bg-primary-600 text-xs font-bold text-white">
                S
              </div>
              <span className="text-sm font-semibold text-primary-900">{t("title")}</span>
            </div>
            <p className="mt-2 text-xs text-primary-500">{t("footerTagline")}</p>
          </div>

          <div className="flex items-center gap-5">
            <Link href="/login" className="text-sm font-medium text-primary-700 hover:text-primary-900">
              {t("login")}
            </Link>
            <LanguageSwitcher />
          </div>
        </div>
        <p className="border-t border-primary-50 px-4 py-4 text-center text-xs text-primary-400">
          © {new Date().getFullYear()} {t("title")}. {t("footerRights")}
        </p>
      </footer>
    </div>
  );
}

function FeatureRow({
  icon: Icon,
  image,
  imageAlt,
  imagePosition,
  title,
  body,
  reverse,
}: {
  icon: React.ComponentType<{ size?: number; strokeWidth?: number }>;
  image: string;
  imageAlt: string;
  imagePosition: string;
  title: string;
  body: string;
  reverse?: boolean;
}) {
  return (
    <div
      className={`grid items-center gap-10 lg:grid-cols-2 lg:gap-16 ${
        reverse ? "lg:[&>*:first-child]:order-2" : ""
      }`}
    >
      <div className="relative mx-auto aspect-[4/5] w-full max-w-sm overflow-hidden rounded-3xl shadow-lg ring-1 ring-primary-900/5 lg:max-w-none">
        <Image
          src={image}
          alt={imageAlt}
          fill
          sizes="(min-width: 1024px) 480px, 90vw"
          className={`object-cover ${imagePosition}`}
        />
      </div>
      <div>
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary-100 text-primary-700">
          <Icon size={18} strokeWidth={2} />
        </div>
        <h3 className="mt-4 text-xl font-semibold tracking-tight text-primary-950 sm:text-2xl">
          {title}
        </h3>
        <p className="mt-3 max-w-md text-base leading-7 text-primary-700">{body}</p>
      </div>
    </div>
  );
}
