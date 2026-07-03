from django.contrib import admin

from .models import GuarantorConsent, Member, MemberDocument, MemberPortalInvite, MemberRelation


class MemberRelationInline(admin.TabularInline):
    model = MemberRelation
    extra = 0


class MemberDocumentInline(admin.TabularInline):
    model = MemberDocument
    extra = 0


@admin.register(Member)
class MemberAdmin(admin.ModelAdmin):
    list_display = ("member_number", "first_name", "last_name", "category", "status", "is_kyc_verified", "date_joined")
    search_fields = ("member_number", "first_name", "last_name", "phone_number", "id_number")
    list_filter = ("category", "status", "is_kyc_verified")
    inlines = [MemberRelationInline, MemberDocumentInline]


@admin.register(GuarantorConsent)
class GuarantorConsentAdmin(admin.ModelAdmin):
    list_display = ("guarantor", "borrower", "status", "requested_at")
    list_filter = ("status",)


@admin.register(MemberPortalInvite)
class MemberPortalInviteAdmin(admin.ModelAdmin):
    list_display = ("member", "status", "created_at", "expires_at")
    readonly_fields = ("token", "accepted_at")
