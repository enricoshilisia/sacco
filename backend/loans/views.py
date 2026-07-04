from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission, user_has_permission
from members.models import Member

from .models import Loan, LoanGuarantor, LoanProduct
from .serializers import (
    AddGuarantorInputSerializer,
    AppraiseInputSerializer,
    DecideInputSerializer,
    DisburseMobileMoneyInputSerializer,
    DisburseToSavingsInputSerializer,
    LoanApplyInputSerializer,
    LoanGuarantorSerializer,
    LoanProductSerializer,
    LoanSerializer,
    MarkDefaultedInputSerializer,
    RecordRepaymentInputSerializer,
    RespondGuaranteeInputSerializer,
)
from .services import (
    add_guarantor,
    appraise_loan,
    apply_for_loan,
    decide_loan,
    disburse_to_savings,
    initiate_loan_disbursement_mobile_money,
    mark_loan_defaulted,
    record_loan_repayment,
    respond_to_guarantee,
    submit_for_appraisal,
)

LOAN_QUERYSET = Loan.objects.select_related("member", "product").prefetch_related(
    "guarantors__guarantor", "schedule", "repayments"
)


def _my_member(request):
    return Member.objects.filter(user=request.user).first()


class LoanProductListCreateView(generics.ListCreateAPIView):
    """Product catalog - not member-specific data, so GET is open to any
    authenticated tenant user (including self-service members choosing what
    to apply for), unlike everything else in this app."""

    queryset = LoanProduct.objects.all()
    serializer_class = LoanProductSerializer

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAuthenticated(), require_permission("loans.manage_products")()]
        return [IsAuthenticated()]


class LoanListView(generics.ListAPIView):
    """Staff-facing: every loan, any member (optionally filtered to one via
    ?member=<id> - e.g. the member detail page's Loans card)."""

    serializer_class = LoanSerializer
    permission_classes = [IsAuthenticated, require_permission("loans.view")]

    def get_queryset(self):
        qs = LOAN_QUERYSET.all()
        member_id = self.request.query_params.get("member")
        if member_id:
            qs = qs.filter(member_id=member_id)
        return qs


class LoanDetailView(APIView):
    """One loan - viewable by staff with loans.view, OR by the loan's own
    borrower, OR by any of its guarantors (self-service, ownership-scoped,
    no permission-catalog check needed for that branch)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        loan = generics.get_object_or_404(LOAN_QUERYSET, pk=pk)
        my_member = _my_member(request)
        is_owner_or_guarantor = my_member is not None and (
            loan.member_id == my_member.id or loan.guarantors.filter(guarantor=my_member).exists()
        )
        if not is_owner_or_guarantor and not user_has_permission(request.user, "loans.view"):
            return Response(status=status.HTTP_403_FORBIDDEN)
        return Response(LoanSerializer(loan).data)


class MyLoansListView(generics.ListAPIView):
    """Self-service: my own loan applications."""

    serializer_class = LoanSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        member = _my_member(self.request)
        if member is None:
            return Loan.objects.none()
        return LOAN_QUERYSET.filter(member=member)


class MyLoanApplyView(APIView):
    permission_classes = [IsAuthenticated, require_permission("loans.apply")]

    def post(self, request):
        member = _my_member(request)
        if member is None:
            return Response(
                {"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND
            )
        serializer = LoanApplyInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            loan = apply_for_loan(member=member, created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanSerializer(loan).data, status=status.HTTP_201_CREATED)


class LoanApplyOnBehalfView(APIView):
    """Staff (e.g. a branch LoanOfficer) submitting an application for a
    member who applied in person rather than through the portal."""

    permission_classes = [IsAuthenticated, require_permission("loans.apply_on_behalf")]

    def post(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        serializer = LoanApplyInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            loan = apply_for_loan(member=member, created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanSerializer(loan).data, status=status.HTTP_201_CREATED)


class AddLoanGuarantorView(APIView):
    """Allocating a guarantor to a loan - the borrower themselves (choosing
    who they'd like to guarantee them) or staff with loans.manage_guarantor_pledge."""

    permission_classes = [IsAuthenticated]

    def post(self, request, loan_id):
        loan = generics.get_object_or_404(Loan, pk=loan_id)
        my_member = _my_member(request)
        is_borrower = my_member is not None and loan.member_id == my_member.id
        if not is_borrower and not user_has_permission(request.user, "loans.manage_guarantor_pledge"):
            return Response(status=status.HTTP_403_FORBIDDEN)
        serializer = AddGuarantorInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            loan_guarantor = add_guarantor(loan=loan, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanGuarantorSerializer(loan_guarantor).data, status=status.HTTP_201_CREATED)


class RespondToGuaranteeView(APIView):
    """Only the guarantor themselves can consent/decline - explicit consent
    means the guarantor's own session, never a staff action on their behalf
    (CLAUDE.md: "Pledges need explicit consent")."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        loan_guarantor = generics.get_object_or_404(LoanGuarantor, pk=pk)
        my_member = _my_member(request)
        if my_member is None or loan_guarantor.guarantor_id != my_member.id:
            return Response(status=status.HTTP_403_FORBIDDEN)
        serializer = RespondGuaranteeInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            loan_guarantor = respond_to_guarantee(
                loan_guarantor=loan_guarantor, accept=serializer.validated_data["accept"]
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanGuarantorSerializer(loan_guarantor).data)


class MyGuaranteeRequestsView(generics.ListAPIView):
    """Self-service: loans I've been asked to guarantee."""

    serializer_class = LoanGuarantorSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        member = _my_member(self.request)
        if member is None:
            return LoanGuarantor.objects.none()
        return LoanGuarantor.objects.filter(guarantor=member).select_related("loan__member", "guarantor")


class SubmitForAppraisalView(APIView):
    """The borrower (once they've lined up enough consenting guarantors) or
    staff with loans.apply_on_behalf moves a loan into the appraisal queue."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        loan = generics.get_object_or_404(Loan, pk=pk)
        my_member = _my_member(request)
        is_borrower = my_member is not None and loan.member_id == my_member.id
        if not is_borrower and not user_has_permission(request.user, "loans.apply_on_behalf"):
            return Response(status=status.HTTP_403_FORBIDDEN)
        try:
            loan = submit_for_appraisal(loan=loan)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanSerializer(loan).data)


class AppraiseLoanView(APIView):
    permission_classes = [IsAuthenticated, require_permission("loans.appraise")]

    def post(self, request, pk):
        loan = generics.get_object_or_404(Loan, pk=pk)
        serializer = AppraiseInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            loan = appraise_loan(loan=loan, appraised_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanSerializer(loan).data)


class DecideLoanView(APIView):
    """Approve needs loans.approve; reject needs loans.reject - granular on
    purpose, so a role could hold one without the other (e.g. a reviewer who
    can only veto, never greenlight)."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        serializer = DecideInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        required_code = "loans.approve" if data["approved"] else "loans.reject"
        if not user_has_permission(request.user, required_code):
            return Response(status=status.HTTP_403_FORBIDDEN)
        loan = generics.get_object_or_404(Loan, pk=pk)
        try:
            loan = decide_loan(loan=loan, approve=data["approved"], decided_by=request.user, notes=data["notes"])
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanSerializer(loan).data)


class DisburseToSavingsView(APIView):
    """Path A: credit the loan straight into one of the member's own
    savings accounts. Synchronous - the loan is ACTIVE, schedule and all,
    by the time this returns."""

    permission_classes = [IsAuthenticated, require_permission("loans.disburse")]

    def post(self, request, pk):
        loan = generics.get_object_or_404(Loan, pk=pk)
        serializer = DisburseToSavingsInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            loan = disburse_to_savings(loan=loan, created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanSerializer(loan).data)


class DisburseMobileMoneyView(APIView):
    """Path B: initiates a mobile-money disbursement. Returns with the loan
    still DISBURSED (not yet ACTIVE) - the provider callback is what moves
    it to ACTIVE, same async shape as an M-Pesa collection."""

    permission_classes = [IsAuthenticated, require_permission("loans.disburse")]

    def post(self, request, pk):
        loan = generics.get_object_or_404(Loan, pk=pk)
        serializer = DisburseMobileMoneyInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            initiate_loan_disbursement_mobile_money(loan=loan, created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        loan.refresh_from_db()
        return Response(LoanSerializer(loan).data)


class RecordLoanRepaymentView(APIView):
    """Staff-recorded repayment (walk-in cash/bank) - self-service member
    repayment via M-Pesa STK is a deliberately separate, not-yet-built
    concern; see loans/services.py:record_loan_repayment's docstring."""

    permission_classes = [IsAuthenticated, require_permission("loans.repay")]

    def post(self, request, pk):
        loan = generics.get_object_or_404(Loan, pk=pk)
        serializer = RecordRepaymentInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            record_loan_repayment(loan=loan, created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        loan.refresh_from_db()
        return Response(LoanSerializer(loan).data)


class MarkLoanDefaultedView(APIView):
    """Manual only - reuses loans.approve (the same authority that decided
    to lend in the first place is who decides a loan has gone bad)."""

    permission_classes = [IsAuthenticated, require_permission("loans.approve")]

    def post(self, request, pk):
        loan = generics.get_object_or_404(Loan, pk=pk)
        serializer = MarkDefaultedInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            loan = mark_loan_defaulted(loan=loan, created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LoanSerializer(loan).data)
