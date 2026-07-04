from dataclasses import dataclass


@dataclass
class CrbResult:
    has_record: bool
    score: int | None
    is_blacklisted: bool
    raw: dict


class CrbProvider:
    """
    Provider-agnostic Credit Reference Bureau interface (BUILD_PLAN.md
    Phase 4: "CRB integration stub for KE (Metropol/TransUnion/Creditinfo) -
    real integration later"). Mirrors payments/providers/base.py's shape -
    which adapter runs is a per-tenant config switch
    (TenantConfig.active_crb_provider via rules_engine/crb/registry.py),
    never a country branch in calling code. No real adapter exists yet;
    only the mock is implemented.
    """

    code = "base"

    def check(self, *, member) -> CrbResult:
        raise NotImplementedError
