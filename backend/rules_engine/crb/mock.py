from .base import CrbProvider, CrbResult


class MockCrbProvider(CrbProvider):
    """
    Stands in for a real KE credit bureau (Metropol/TransUnion/Creditinfo)
    until one is integrated. Deterministic, same "magic suffix" testing
    convention as MockPaymentProvider (payments/providers/mock.py): a
    member whose id_number ends in "0000" simulates a blacklisted record
    with a low score, so both the auto-deny and auto-approve paths are
    reachable in tests without a real bureau. This is the default active
    CRB provider for every tenant until an admin configures a real one.
    """

    code = "mock"

    def check(self, *, member) -> CrbResult:
        if member.id_number.endswith("0000"):
            return CrbResult(has_record=True, score=300, is_blacklisted=True, raw={})
        return CrbResult(has_record=True, score=750, is_blacklisted=False, raw={})
