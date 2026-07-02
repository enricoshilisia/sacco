from django.core.management.base import BaseCommand, CommandError

from tenants.models import COUNTRY_DEFAULTS, Country, Domain, Tenant


class Command(BaseCommand):
    help = "Provision a new SACCO tenant: creates its schema and primary domain."

    def add_arguments(self, parser):
        parser.add_argument("--name", required=True, help="SACCO display name")
        parser.add_argument("--schema", required=True, help="Postgres schema name (lowercase, no spaces)")
        parser.add_argument("--domain", required=True, help="Domain/subdomain used to route to this tenant")
        parser.add_argument("--country", required=True, choices=[c.value for c in Country])

    def handle(self, *args, **options):
        country = options["country"]
        defaults = COUNTRY_DEFAULTS[country]

        if Tenant.objects.filter(schema_name=options["schema"]).exists():
            raise CommandError(f"Tenant with schema '{options['schema']}' already exists")

        tenant = Tenant.objects.create(
            schema_name=options["schema"],
            name=options["name"],
            country=country,
            currency=defaults["currency"],
            default_language=defaults["language"],
        )
        Domain.objects.create(domain=options["domain"], tenant=tenant, is_primary=True)

        self.stdout.write(
            self.style.SUCCESS(
                f"Created tenant '{tenant.name}' (schema={tenant.schema_name}, "
                f"domain={options['domain']}, country={country}, currency={defaults['currency']})"
            )
        )
