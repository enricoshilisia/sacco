"""Writing audit events, and reading who/where/which device from a request."""

import ipaddress
import logging
import re
from decimal import Decimal, InvalidOperation
from urllib.parse import unquote

from django.conf import settings

from .models import AuditAction, AuditEvent

logger = logging.getLogger(__name__)

UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)


def client_ip(request) -> str | None:
    # Only trust X-Forwarded-For behind a proxy we run (settings), otherwise
    # anyone could claim any address.
    if getattr(settings, "AUDIT_TRUST_X_FORWARDED_FOR", False):
        forwarded = request.META.get("HTTP_X_FORWARDED_FOR", "")
        if forwarded:
            return forwarded.split(",")[0].strip() or None
    return request.META.get("REMOTE_ADDR") or None


def _ip_location(ip: str | None) -> str:
    if not ip:
        return ""
    try:
        address = ipaddress.ip_address(ip)
    except ValueError:
        return ""
    if address.is_private or address.is_loopback:
        return "Local network"
    path = getattr(settings, "GEOIP_CITY_DB", "")
    if not path:
        return ""
    try:  # optional: pip install geoip2 + a GeoLite2-City.mmdb file
        import geoip2.database

        with geoip2.database.Reader(path) as reader:
            city = reader.city(ip)
        return ", ".join(filter(None, [city.city.name, city.country.name])) + " (by IP)"
    except Exception:  # noqa: BLE001 - location is best-effort
        return ""


def client_context(request) -> dict:
    """Where and on what. The app sends X-Client-Device (e.g. "Samsung
    SM-A515F · Android 13 · Inuka West 1.0.3") and, when the person allowed
    location, X-Client-Location ("-1.2833,36.8167;Nairobi, Kenya", the
    place name URL-encoded). Otherwise location falls back to the IP."""
    if request is None:
        return {}
    ip = client_ip(request)
    context = {
        "ip_address": ip,
        "device": unquote(request.META.get("HTTP_X_CLIENT_DEVICE", ""))[:200],
        "user_agent": request.META.get("HTTP_USER_AGENT", "")[:300],
        "location": "",
        "latitude": None,
        "longitude": None,
    }
    raw = request.META.get("HTTP_X_CLIENT_LOCATION", "")
    if raw:
        coords, _, place = raw.partition(";")
        try:
            lat, lng = (Decimal(part.strip()) for part in coords.split(",", 1))
            if -90 <= lat <= 90 and -180 <= lng <= 180:
                context["latitude"] = lat.quantize(Decimal("0.000001"))
                context["longitude"] = lng.quantize(Decimal("0.000001"))
        except (ValueError, InvalidOperation):
            pass
        context["location"] = unquote(place).strip()[:200]
    if not context["location"]:
        context["location"] = _ip_location(ip)
    if not context["device"]:
        context["device"] = _device_from_user_agent(context["user_agent"])
    return context


def _device_from_user_agent(ua: str) -> str:
    if not ua:
        return ""
    for needle, label in (("Android", "Android"), ("iPhone", "iPhone"), ("iPad", "iPad"),
                          ("Windows", "Windows"), ("Macintosh", "Mac"), ("Linux", "Linux")):
        if needle in ua:
            browser = next((b for b in ("Edg", "Chrome", "Firefox", "Safari") if b in ua), "")
            browser = {"Edg": "Edge"}.get(browser, browser)
            return f"{label} · {browser} (web)" if browser else label
    return ua[:60]


def actor_label(user) -> str:
    if user is None or not getattr(user, "is_authenticated", False):
        return ""
    name = f"{user.first_name} {user.last_name}".strip()
    return f"{name} ({user.phone_number})" if name else user.phone_number


def record(*, request=None, user=None, action=AuditAction.EVENT, summary: str, event: str = "", area: str = "",
           target=None, target_label: str = "", status_code=None, method: str = "", path: str = "",
           duration_ms=None, actor: str = "", target_id: str = "") -> AuditEvent | None:
    """Never raises: a failure to audit is logged loudly rather than
    breaking the action that was being audited (which has already
    happened by the time most events are written)."""
    try:
        if user is None and request is not None:
            candidate = getattr(request, "user", None)
            user = candidate if getattr(candidate, "is_authenticated", False) else None
        return AuditEvent.objects.create(
            user=user,
            actor=actor or actor_label(user),
            action=action,
            event=event,
            area=area,
            summary=summary[:300],
            method=method,
            path=path[:300],
            status_code=status_code,
            target_type=target.__class__.__name__ if target is not None else "",
            target_id=str(getattr(target, "pk", "") or "") if target is not None else target_id,
            target_label=(target_label or (str(target) if target is not None else ""))[:200],
            duration_ms=duration_ms,
            **client_context(request),
        )
    except Exception:  # noqa: BLE001
        logger.exception("Could not write audit event: %s", summary)
        return None


# --- Describing API requests in plain words ----------------------------------

_VERBS = {"GET": ("Viewed", AuditAction.VIEW), "POST": ("Submitted", AuditAction.CREATE),
          "PUT": ("Changed", AuditAction.UPDATE), "PATCH": ("Changed", AuditAction.UPDATE),
          "DELETE": ("Deleted", AuditAction.DELETE)}


def describe(method: str, path: str) -> tuple[str, str, str, str]:
    """-> (action, area, summary, target_id) for an /api/ request."""
    verb, action = _VERBS.get(method, (method, AuditAction.VIEW))
    parts = [p for p in path.strip("/").split("/")[1:] if p]  # drop "api"
    target_id = next((p for p in parts if UUID_RE.fullmatch(p)), "")
    words = [p.replace("-", " ").replace("_", " ") for p in parts if not UUID_RE.fullmatch(p)]
    area = words[0] if words else ""
    if method == "POST" and words and words[-1] in {
        "approve", "reject", "confirm", "dismiss", "cancel", "close", "revoke", "accept", "disburse",
        "reactivate", "reset password", "disable", "enable", "assign", "remove", "run", "respond",
    }:
        verb = words[-1].capitalize()
        words = words[:-1]
    thing = " › ".join(words) or "home"
    if target_id and method == "GET":
        thing += " (one record)"
    return action, area[:40], f"{verb} {thing}", target_id
