"""
Django settings for the SACCO platform.

Multi-tenant (schema-per-tenant via django-tenants). See CLAUDE.md at the
repo root for the non-negotiable rules this project is built against.
"""

from datetime import timedelta
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent

env = environ.Env()
environ.Env.read_env(BASE_DIR.parent / ".env")

SECRET_KEY = env("DJANGO_SECRET_KEY", default="django-insecure-dev-only-change-me")
DEBUG = env.bool("DJANGO_DEBUG", default=True)
ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=["localhost", "127.0.0.1"])

# ---------------------------------------------------------------------------
# Multi-tenancy (django-tenants: schema-per-tenant)
# ---------------------------------------------------------------------------

SHARED_APPS = [
    "django_tenants",
    "tenants",  # Tenant + Domain models must live in a SHARED_APPS app
    "identity",  # custom User is shared: a person can belong to many SACCOs

    "django.contrib.contenttypes",
    "django.contrib.auth",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.admin",

    "rest_framework",
    "rest_framework_simplejwt",
    "corsheaders",
    "django_celery_beat",
    "django_celery_results",
]

TENANT_APPS = [
    "django.contrib.contenttypes",

    "core",
    "configuration",
    "accesscontrol",
]

INSTALLED_APPS = list(SHARED_APPS) + [app for app in TENANT_APPS if app not in SHARED_APPS]

TENANT_MODEL = "tenants.Tenant"
TENANT_DOMAIN_MODEL = "tenants.Domain"

DATABASE_ROUTERS = ("django_tenants.routers.TenantSyncRouter",)

MIDDLEWARE = [
    "django_tenants.middleware.main.TenantMainMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.locale.LocaleMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

DATABASES = {
    "default": {
        "ENGINE": "django_tenants.postgresql_backend",
        "NAME": env("POSTGRES_DB", default="sacco"),
        "USER": env("POSTGRES_USER", default="sacco"),
        "PASSWORD": env("POSTGRES_PASSWORD", default="change-me-locally"),
        "HOST": env("POSTGRES_HOST", default="localhost"),
        "PORT": env("POSTGRES_PORT", default="5432"),
    }
}

AUTH_USER_MODEL = "identity.User"

# ---------------------------------------------------------------------------
# Password validation
# ---------------------------------------------------------------------------

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ---------------------------------------------------------------------------
# Internationalization â€” English + Swahili from day one (Kenya & Tanzania)
# ---------------------------------------------------------------------------

LANGUAGE_CODE = "en"
TIME_ZONE = "Africa/Nairobi"
USE_I18N = True
USE_TZ = True

LANGUAGES = [
    ("en", "English"),
    ("sw", "Kiswahili"),
]

LOCALE_PATHS = [BASE_DIR / "locale"]

# ---------------------------------------------------------------------------
# Static files
# ---------------------------------------------------------------------------

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ---------------------------------------------------------------------------
# Object storage (S3-compatible: MinIO on-prem, S3 in the cloud)
# ---------------------------------------------------------------------------

STORAGES = {
    "default": {
        "BACKEND": "storages.backends.s3.S3Storage",
    },
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
    },
}

AWS_ACCESS_KEY_ID = env("MINIO_ROOT_USER", default="sacco_minio")
AWS_SECRET_ACCESS_KEY = env("MINIO_ROOT_PASSWORD", default="change-me-locally")
AWS_STORAGE_BUCKET_NAME = env("MINIO_BUCKET", default="sacco-documents")
AWS_S3_ENDPOINT_URL = env("MINIO_ENDPOINT_URL", default="http://localhost:9000")
AWS_S3_ADDRESSING_STYLE = "path"
AWS_DEFAULT_ACL = None
AWS_QUERYSTRING_AUTH = True

# ---------------------------------------------------------------------------
# REST framework / auth
# ---------------------------------------------------------------------------

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 25,
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=30),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
}

CORS_ALLOWED_ORIGINS = env.list(
    "CORS_ALLOWED_ORIGINS", default=["http://localhost:3000"]
)
CORS_ALLOW_CREDENTIALS = True

# ---------------------------------------------------------------------------
# Celery
# ---------------------------------------------------------------------------

CELERY_BROKER_URL = env("CELERY_BROKER_URL", default="redis://localhost:6379/0")
CELERY_RESULT_BACKEND = "django-db"
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_ALWAYS_EAGER = env.bool("CELERY_TASK_ALWAYS_EAGER", default=False)

# ---------------------------------------------------------------------------
# WebAuthn (biometric / passkey authentication)
# ---------------------------------------------------------------------------

WEBAUTHN_RP_ID = env("WEBAUTHN_RP_ID", default="localhost")
WEBAUTHN_RP_NAME = env("WEBAUTHN_RP_NAME", default="SACCO Platform")
WEBAUTHN_ORIGIN = env("WEBAUTHN_ORIGIN", default="http://localhost:3000")

# ---------------------------------------------------------------------------
# Firebase Cloud Messaging (push notifications)
# ---------------------------------------------------------------------------

FIREBASE_PROJECT_ID = env("FIREBASE_PROJECT_ID", default="")
FIREBASE_SERVICE_ACCOUNT_JSON_PATH = env("FIREBASE_SERVICE_ACCOUNT_JSON_PATH", default="")

# ---------------------------------------------------------------------------
# SMS providers: KE primary=HostPinnacle, TZ primary=Beem, backup=Africa's Talking
# ---------------------------------------------------------------------------

HOSTPINNACLE_API_KEY = env("HOSTPINNACLE_API_KEY", default="")
HOSTPINNACLE_API_SECRET = env("HOSTPINNACLE_API_SECRET", default="")
HOSTPINNACLE_SENDER_ID = env("HOSTPINNACLE_SENDER_ID", default="")

BEEM_API_KEY = env("BEEM_API_KEY", default="")
BEEM_SECRET_KEY = env("BEEM_SECRET_KEY", default="")
BEEM_SENDER_ID = env("BEEM_SENDER_ID", default="")

AFRICASTALKING_USERNAME = env("AFRICASTALKING_USERNAME", default="")
AFRICASTALKING_API_KEY = env("AFRICASTALKING_API_KEY", default="")
AFRICASTALKING_SENDER_ID = env("AFRICASTALKING_SENDER_ID", default="")

# ---------------------------------------------------------------------------
# Payment providers: KE=Daraja (M-Pesa), TZ=Selcom
# ---------------------------------------------------------------------------

DARAJA_CONSUMER_KEY = env("DARAJA_CONSUMER_KEY", default="")
DARAJA_CONSUMER_SECRET = env("DARAJA_CONSUMER_SECRET", default="")
DARAJA_SHORTCODE = env("DARAJA_SHORTCODE", default="")
DARAJA_PASSKEY = env("DARAJA_PASSKEY", default="")
DARAJA_ENV = env("DARAJA_ENV", default="sandbox")

SELCOM_API_KEY = env("SELCOM_API_KEY", default="")
SELCOM_API_SECRET = env("SELCOM_API_SECRET", default="")
SELCOM_VENDOR_ID = env("SELCOM_VENDOR_ID", default="")
SELCOM_ENV = env("SELCOM_ENV", default="sandbox")
