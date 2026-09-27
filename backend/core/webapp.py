"""
Serves the Flutter web build (the same app iPhone users add to their Home
screen) from this server, so it shares the SACCO's domain: no separate
host, no CORS, and the tenant is picked by the hostname as usual.
"""

from pathlib import Path

from django.conf import settings
from django.http import Http404
from django.views.static import serve


def webapp(request, path=""):
    """Serves one file of the build, falling back to index.html so deep
    links and a refresh inside the app still work."""
    root = Path(settings.WEBAPP_ROOT)
    if not root.exists():
        raise Http404("The web app has not been built yet.")
    candidate = (root / path).resolve()
    if path and root.resolve() in candidate.parents and candidate.is_file():
        return serve(request, path, document_root=str(root))
    return serve(request, "index.html", document_root=str(root))
