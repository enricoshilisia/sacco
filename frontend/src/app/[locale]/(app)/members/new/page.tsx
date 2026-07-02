"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { ArrowLeft, ArrowRight, Check, Plus, X } from "lucide-react";
import { Link, useRouter } from "@/i18n/navigation";
import { apiFetch } from "@/lib/api";

const ALL_ID_TYPES = ["NATIONAL_ID", "HUDUMA", "NIDA", "PASSPORT"] as const;

const inputClass =
  "w-full rounded-lg border border-primary-200 bg-white px-4 py-3 text-base text-primary-900 placeholder:text-primary-400 focus:border-primary-500 focus:outline-none focus:ring-1 focus:ring-primary-500";

type Relation = {
  kind: "NEXT_OF_KIN" | "NOMINEE" | "BENEFICIARY";
  full_name: string;
  relationship: string;
  phone_number: string;
  id_number: string;
  benefit_percentage: string;
};

const initialForm = {
  category: "ORDINARY",
  first_name: "",
  last_name: "",
  other_names: "",
  date_of_birth: "",
  gender: "",
  id_type: "NATIONAL_ID",
  id_number: "",
  phone_number: "",
  email: "",
  physical_address: "",
};

const emptyRelation: Relation = {
  kind: "NEXT_OF_KIN",
  full_name: "",
  relationship: "",
  phone_number: "",
  id_number: "",
  benefit_percentage: "",
};

const STEP_KEYS = ["stepPersonal", "stepIdContact", "stepRelations"] as const;

export default function NewMemberPage() {
  const t = useTranslations("Members");
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [form, setForm] = useState(initialForm);
  const [allowedIdTypes, setAllowedIdTypes] = useState<string[]>([...ALL_ID_TYPES]);
  const [relations, setRelations] = useState<Relation[]>([]);
  const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");

  useEffect(() => {
    apiFetch<{ allowed_id_types: string[] }>("/api/settings/")
      .then(({ allowed_id_types }) => {
        const types = allowed_id_types.length > 0 ? allowed_id_types : [...ALL_ID_TYPES];
        setAllowedIdTypes(types);
        setForm((f) => (types.includes(f.id_type) ? f : { ...f, id_type: types[0] }));
      })
      .catch(() => {});
  }, []);

  function field(name: keyof typeof initialForm) {
    return {
      value: form[name],
      onChange: (e: React.ChangeEvent<HTMLInputElement>) =>
        setForm({ ...form, [name]: e.target.value }),
    };
  }

  function updateRelation(index: number, patch: Partial<Relation>) {
    setRelations(relations.map((r, i) => (i === index ? { ...r, ...patch } : r)));
  }

  const isLastStep = step === STEP_KEYS.length - 1;

  function goNext() {
    setStep((s) => Math.min(s + 1, STEP_KEYS.length - 1));
  }
  function goBack() {
    setStep((s) => Math.max(s - 1, 0));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!isLastStep) {
      goNext();
      return;
    }
    setStatus("loading");
    try {
      const payload = {
        ...form,
        date_of_birth: form.date_of_birth || null,
        relations: relations.map((r) => ({
          ...r,
          benefit_percentage: r.kind === "BENEFICIARY" && r.benefit_percentage ? r.benefit_percentage : null,
        })),
      };
      const created = await apiFetch<{ id: string }>("/api/members/", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      router.push(`/members/${created.id}`);
    } catch {
      setStatus("error");
    }
  }

  return (
    <div className="mx-auto max-w-2xl">
      <Link
        href="/members"
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-primary-600 hover:text-primary-800"
      >
        <ArrowLeft size={16} />
        {t("title")}
      </Link>

      <h1 className="mb-6 text-xl font-semibold text-primary-900">{t("newTitle")}</h1>

      <StepIndicator step={step} labels={STEP_KEYS.map((key) => t(key))} />

      <form onSubmit={handleSubmit}>
        {step === 0 && (
          <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
            <div className="mb-4 grid grid-cols-2 gap-3">
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("firstName")}</span>
                <input required className={inputClass} {...field("first_name")} />
              </label>
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("lastName")}</span>
                <input required className={inputClass} {...field("last_name")} />
              </label>
            </div>

            <label className="mb-4 block">
              <span className="mb-1 block text-sm font-medium text-primary-800">{t("otherNames")}</span>
              <input className={inputClass} {...field("other_names")} />
            </label>

            <div className="mb-4 grid grid-cols-2 gap-3">
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("dateOfBirth")}</span>
                <input type="date" className={inputClass} {...field("date_of_birth")} />
              </label>
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("gender")}</span>
                <select
                  value={form.gender}
                  onChange={(e) => setForm({ ...form, gender: e.target.value })}
                  className={inputClass}
                >
                  <option value="">-</option>
                  <option value="FEMALE">{t("genderFemale")}</option>
                  <option value="MALE">{t("genderMale")}</option>
                  <option value="OTHER">{t("genderOther")}</option>
                </select>
              </label>
            </div>

            <label className="block">
              <span className="mb-1 block text-sm font-medium text-primary-800">{t("category")}</span>
              <select
                value={form.category}
                onChange={(e) => setForm({ ...form, category: e.target.value })}
                className={inputClass}
              >
                <option value="ORDINARY">{t("categoryOrdinary")}</option>
                <option value="ASSOCIATE">{t("categoryAssociate")}</option>
                <option value="JUNIOR">{t("categoryJunior")}</option>
                <option value="CORPORATE">{t("categoryCorporate")}</option>
              </select>
            </label>
          </div>
        )}

        {step === 1 && (
          <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
            <div className="mb-4 grid grid-cols-2 gap-3">
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("idType")}</span>
                <select
                  value={form.id_type}
                  onChange={(e) => setForm({ ...form, id_type: e.target.value })}
                  className={inputClass}
                >
                  {allowedIdTypes.includes("NATIONAL_ID") && (
                    <option value="NATIONAL_ID">{t("idNational")}</option>
                  )}
                  {allowedIdTypes.includes("HUDUMA") && (
                    <option value="HUDUMA">{t("idHuduma")}</option>
                  )}
                  {allowedIdTypes.includes("NIDA") && <option value="NIDA">{t("idNida")}</option>}
                  {allowedIdTypes.includes("PASSPORT") && (
                    <option value="PASSPORT">{t("idPassport")}</option>
                  )}
                </select>
              </label>
              <label className="block">
                <span className="mb-1 block text-sm font-medium text-primary-800">{t("idNumber")}</span>
                <input required className={inputClass} {...field("id_number")} />
              </label>
            </div>

            <label className="mb-4 block">
              <span className="mb-1 block text-sm font-medium text-primary-800">{t("phoneNumber")}</span>
              <input type="tel" required inputMode="tel" className={inputClass} {...field("phone_number")} />
            </label>

            <label className="mb-4 block">
              <span className="mb-1 block text-sm font-medium text-primary-800">{t("email")}</span>
              <input type="email" className={inputClass} {...field("email")} />
            </label>

            <label className="block">
              <span className="mb-1 block text-sm font-medium text-primary-800">{t("physicalAddress")}</span>
              <input className={inputClass} {...field("physical_address")} />
            </label>
          </div>
        )}

        {step === 2 && (
          <div className="mb-6 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-primary-100/80">
            <h2 className="mb-4 text-sm font-semibold text-primary-800">{t("relationsSection")}</h2>

            {relations.map((relation, index) => (
              <div key={index} className="mb-4 rounded-lg border border-primary-100 p-4">
                <div className="mb-3 grid grid-cols-2 gap-3">
                  <select
                    value={relation.kind}
                    onChange={(e) => updateRelation(index, { kind: e.target.value as Relation["kind"] })}
                    className={inputClass}
                  >
                    <option value="NEXT_OF_KIN">{t("kindNextOfKin")}</option>
                    <option value="NOMINEE">{t("kindNominee")}</option>
                    <option value="BENEFICIARY">{t("kindBeneficiary")}</option>
                  </select>
                  <input
                    placeholder={t("relationship")}
                    value={relation.relationship}
                    onChange={(e) => updateRelation(index, { relationship: e.target.value })}
                    className={inputClass}
                  />
                </div>
                <input
                  placeholder={t("relationName")}
                  value={relation.full_name}
                  onChange={(e) => updateRelation(index, { full_name: e.target.value })}
                  className={`${inputClass} mb-3`}
                />
                <div className="grid grid-cols-2 gap-3">
                  <input
                    placeholder={t("phoneNumber")}
                    value={relation.phone_number}
                    onChange={(e) => updateRelation(index, { phone_number: e.target.value })}
                    className={inputClass}
                  />
                  {relation.kind === "BENEFICIARY" && (
                    <input
                      type="number"
                      min="0"
                      max="100"
                      placeholder={t("benefitPercentage")}
                      value={relation.benefit_percentage}
                      onChange={(e) => updateRelation(index, { benefit_percentage: e.target.value })}
                      className={inputClass}
                    />
                  )}
                </div>
                <button
                  type="button"
                  onClick={() => setRelations(relations.filter((_, i) => i !== index))}
                  className="mt-3 inline-flex items-center gap-1 text-sm text-red-600 hover:underline"
                >
                  <X size={14} />
                  {t("removeRelation")}
                </button>
              </div>
            ))}

            <button
              type="button"
              onClick={() => setRelations([...relations, { ...emptyRelation }])}
              className="inline-flex items-center gap-1.5 rounded-full border border-primary-300 bg-white px-4 py-2 text-sm font-medium text-primary-800 hover:bg-primary-50"
            >
              <Plus size={16} />
              {t("addRelation")}
            </button>
          </div>
        )}

        {status === "error" && <p className="mb-4 text-sm text-red-600">{t("error")}</p>}

        <div className="flex items-center justify-between gap-3">
          <button
            type="button"
            onClick={goBack}
            disabled={step === 0}
            className="inline-flex items-center gap-1.5 rounded-full border border-primary-200 bg-white px-5 py-2.5 text-sm font-semibold text-primary-800 transition-colors hover:bg-primary-50 disabled:cursor-not-allowed disabled:opacity-0"
          >
            <ArrowLeft size={16} />
            {t("stepBack")}
          </button>

          <button
            type="submit"
            disabled={status === "loading"}
            className="inline-flex items-center gap-1.5 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-primary-700 disabled:opacity-60"
          >
            {isLastStep ? t("submit") : t("stepNext")}
            {isLastStep ? null : <ArrowRight size={16} />}
          </button>
        </div>
      </form>
    </div>
  );
}

function StepIndicator({ step, labels }: { step: number; labels: string[] }) {
  return (
    <div className="mb-6 flex items-center">
      {labels.map((label, index) => (
        <div key={label} className="flex flex-1 items-center last:flex-none">
          <div className="flex flex-col items-center gap-1.5">
            <div
              className={
                "flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-sm font-semibold transition-colors " +
                (index < step
                  ? "bg-primary-600 text-white"
                  : index === step
                    ? "bg-primary-600 text-white ring-4 ring-primary-100"
                    : "bg-primary-100 text-primary-400")
              }
            >
              {index < step ? <Check size={16} /> : index + 1}
            </div>
            <span
              className={
                "hidden text-xs font-medium sm:block " +
                (index <= step ? "text-primary-700" : "text-primary-400")
              }
            >
              {label}
            </span>
          </div>
          {index < labels.length - 1 && (
            <div
              className={
                "mx-2 h-0.5 flex-1 rounded transition-colors " +
                (index < step ? "bg-primary-600" : "bg-primary-100")
              }
            />
          )}
        </div>
      ))}
    </div>
  );
}
