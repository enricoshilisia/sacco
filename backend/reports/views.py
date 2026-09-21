import csv
from datetime import date

from django.db import connection
from django.http import HttpResponse
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission, user_has_permission
from accounting.models import Account

from . import services

# key -> (builder, parameters, permission to view it). Each report needs its
# own data permission - reports.view alone is held by tellers and committee
# members, who must not see the full ledger or every member's balances.
REPORTS = {
    "trial_balance": (services.trial_balance, "as_of", "accounting.view_trial_balance"),
    "balance_sheet": (services.balance_sheet, "as_of", "accounting.view_trial_balance"),
    "income_statement": (services.income_statement, "period", "accounting.view_trial_balance"),
    "general_ledger": (services.general_ledger, "account_period", "accounting.view_ledger"),
    "journal": (services.journal, "period", "accounting.view_ledger"),
    "member_balances": (services.member_balances, "as_of", "accounting.view_ledger"),
    "loan_portfolio": (services.loan_portfolio, "as_of", "loans.view"),
    "collections": (services.collections, "period", "payments.view_transactions"),
    "distribution_register": (services.distribution_register, "period", "distributions.view"),
}


def _parse_date(value, default):
    if not value:
        return default
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise ValueError(_("Dates must be YYYY-MM-DD."))


class ReportCatalogView(APIView):
    """The reports this leader can open, and what each one needs."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        can_export = user_has_permission(request.user, "reports.export")
        return Response({
            "can_export": can_export,
            "reports": [
                {"key": key, "params": params}
                for key, (_builder, params, permission) in REPORTS.items()
                if user_has_permission(request.user, permission)
            ],
        })


class ReportView(APIView):
    """GET /api/reports/<key>/?as_of= | ?start=&end= [&account=CODE] [&export=csv]"""

    permission_classes = [IsAuthenticated]

    def get(self, request, key):
        if key not in REPORTS:
            return Response({"detail": _("Unknown report.")}, status=status.HTTP_404_NOT_FOUND)
        builder, params, permission = REPORTS[key]
        if not user_has_permission(request.user, permission):
            raise PermissionDenied()
        export = request.query_params.get("export") == "csv"
        if export and not user_has_permission(request.user, "reports.export"):
            raise PermissionDenied(_("Exporting reports needs the reports.export permission."))

        today = date.today()
        try:
            if params == "as_of":
                report = builder(as_of=_parse_date(request.query_params.get("as_of"), today))
            else:
                start = _parse_date(request.query_params.get("start"), date(today.year, 1, 1))
                end = _parse_date(request.query_params.get("end"), today)
                if start > end:
                    raise ValueError(_("The start date must be on or before the end date."))
                if params == "account_period":
                    code = request.query_params.get("account", "")
                    if not Account.objects.filter(code=code).exists():
                        raise ValueError(_("Choose an account."))
                    report = builder(account_code=code, start=start, end=end)
                else:
                    report = builder(start=start, end=end)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        report["key"] = key
        report["generated_at"] = timezone.now().isoformat()
        report["generated_by"] = request.user.get_full_name()
        if export:
            return _csv_response(report)
        return Response(report)


def _csv_response(report) -> HttpResponse:
    from tenants.models import Tenant

    tenant = Tenant.objects.filter(schema_name=connection.schema_name).first()
    response = HttpResponse(content_type="text/csv; charset=utf-8")
    filename = f"{report['key']}_{date.today().isoformat()}.csv"
    response["Content-Disposition"] = f'attachment; filename="{filename}"'
    response.write("﻿")  # BOM so Excel opens UTF-8 (Swahili names) correctly
    writer = csv.writer(response)
    writer.writerow([tenant.name if tenant else ""])
    writer.writerow([report["title"]])
    writer.writerow([_("Period"), report["period"]])
    if tenant:
        writer.writerow([_("Currency"), tenant.currency])
    writer.writerow([_("Generated"), report["generated_at"], _("by"), report["generated_by"]])
    writer.writerow([])
    if report["summary"]:
        for item in report["summary"]:
            writer.writerow([item["label"], item["value"]])
        writer.writerow([])
    for section in report["sections"]:
        writer.writerow([section["title"]])
        writer.writerow([c["label"] for c in section["columns"]])
        writer.writerows(section["rows"])
        if section.get("totals"):
            writer.writerow(section["totals"])
        writer.writerow([])
    if report["checks"]:
        writer.writerow([_("Checks")])
        for check in report["checks"]:
            writer.writerow([check["label"], _("OK") if check["ok"] else _("DIFFERENCE"), check["detail"]])
    return response


class FinanceSummaryView(APIView):
    """Treasurer / accountant dashboard figures."""

    permission_classes = [IsAuthenticated, require_permission("accounting.view_trial_balance")]

    def get(self, request):
        return Response(services.finance_summary())


class MyTasksView(APIView):
    """Counts of what's waiting on this leader (approvals, disbursements...)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({"tasks": services.my_tasks(request.user)})
