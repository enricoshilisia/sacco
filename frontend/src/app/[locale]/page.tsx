import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import LanguageSwitcher from "@/components/LanguageSwitcher";

export default function Home() {
  const t = useTranslations("Home");

  return (
    <div className="flex min-h-full flex-col bg-primary-50">
      <header className="flex items-center justify-between px-4 py-4 sm:px-6">
        <span className="text-lg font-semibold text-primary-800">{t("title")}</span>
        <LanguageSwitcher />
      </header>

      <main className="flex flex-1 flex-col items-center justify-center px-6 py-10 text-center">
        <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100 sm:p-8">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-primary-600 text-2xl font-bold text-white">
            S
          </div>
          <h1 className="text-xl font-semibold text-primary-900">{t("title")}</h1>
          <p className="mt-2 text-sm leading-6 text-primary-700">{t("tagline")}</p>

          <div className="mt-6 flex flex-col gap-3">
            <Link
              href="/login"
              className="w-full rounded-full bg-primary-600 px-5 py-3 text-center text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 active:bg-primary-800"
            >
              {t("login")}
            </Link>
            <Link
              href="/register"
              className="w-full rounded-full border border-primary-200 bg-white px-5 py-3 text-center text-sm font-semibold text-primary-800 transition-colors hover:bg-primary-50"
            >
              {t("register")}
            </Link>
          </div>
        </div>
      </main>
    </div>
  );
}
