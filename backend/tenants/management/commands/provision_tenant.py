from django.core.management.base import BaseCommand, CommandError

from tenants.models import Country
from tenants.services import provision_tenant


class Command(BaseCommand):
    help = "Provision a new SACCO tenant: creates its schema and primary domain."

    def add_arguments(self, parser):
        parser.add_argument("--name", required=True, help="SACCO display name")
        parser.add_argument("--schema", required=True, help="Postgres schema name (lowercase, no spaces)")
        parser.add_argument("--domain", required=True, help="Domain/subdomain used to route to this tenant")
        parser.add_argument("--country", required=True, choices=[c.value for c in Country])

    def handle(self, *args, **options):
        try:
            tenant = provision_tenant(
                name=options["name"],
                schema_name=options["schema"],
                domain=options["domain"],
                country=options["country"],
            )
        except ValueError as exc:
            raise CommandError(str(exc)) from exc

        self.stdout.write(
            self.style.SUCCESS(
                f"Created tenant '{tenant.name}' (schema={tenant.schema_name}, "
                f"domain={options['domain']}, country={tenant.country}, currency={tenant.currency})"
            )
        )
