from django.conf import settings
from storages.backends.s3 import S3Storage


class PublicUrlS3Storage(S3Storage):
    """
    Same as django-storages' S3Storage, except generated URLs get their host
    rewritten from the internal MinIO endpoint (what Django itself uses to
    talk to MinIO - localhost, fast, no NAT hairpin issues) to a publicly
    reachable one (what a browser on someone else's machine needs).

    Signed query-string auth (AWSAccessKeyId/Signature/Expires) is MinIO's
    SigV2 scheme, which signs the HTTP method, content headers, expiry, and
    canonicalized resource path - never the Host - so rewriting just the
    scheme/host/port here doesn't invalidate the signature. This keeps
    URLs time-limited and signed rather than falling back to
    AWS_S3_CUSTOM_DOMAIN's unsigned/permanently-public URL mode, which
    would make member photos and SACCO logos world-readable forever.
    """

    def url(self, name, parameters=None, expire=None, http_method=None):
        url = super().url(name, parameters, expire, http_method)
        public_endpoint = getattr(settings, "AWS_S3_PUBLIC_ENDPOINT_URL", "")
        internal_endpoint = settings.AWS_S3_ENDPOINT_URL
        if public_endpoint and url.startswith(internal_endpoint):
            url = public_endpoint + url[len(internal_endpoint):]
        return url
