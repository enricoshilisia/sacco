import shutil
import tempfile
from io import BytesIO

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, override_settings
from django_tenants.test.cases import TenantTestCase
from django_tenants.test.client import TenantClient
from PIL import Image

from accesscontrol.models import Membership, Role
from core.images import InvalidImage, normalize_image
from identity.models import User

from .models import Member


def _image_bytes(fmt="JPEG", size=(4000, 3000), mode="RGB", exif_orientation=None):
    image = Image.new(mode, size, (200, 60, 40, 128) if mode == "RGBA" else (200, 60, 40))
    out = BytesIO()
    kwargs = {}
    if exif_orientation:
        exif = Image.Exif()
        exif[0x0112] = exif_orientation
        kwargs["exif"] = exif
    image.save(out, format=fmt, **kwargs)
    return out.getvalue()


class NormalizeImageTests(SimpleTestCase):
    def _open(self, content_file):
        return Image.open(BytesIO(content_file.read()))

    def test_large_phone_photo_is_shrunk_to_a_jpeg(self):
        result = self._open(normalize_image(SimpleUploadedFile("big.jpg", _image_bytes(size=(4000, 3000)))))
        self.assertEqual(result.format, "JPEG")
        self.assertEqual(max(result.size), 1024)

    def test_png_with_transparency_becomes_a_white_backed_jpeg(self):
        result = self._open(normalize_image(SimpleUploadedFile("a.png", _image_bytes("PNG", (800, 600), "RGBA"))))
        self.assertEqual((result.format, result.mode), ("JPEG", "RGB"))

    def test_sideways_phone_photo_is_rotated_upright(self):
        # EXIF orientation 6 = rotate 90 degrees; a 4000x3000 landscape becomes portrait.
        result = self._open(normalize_image(SimpleUploadedFile("r.jpg", _image_bytes(exif_orientation=6))))
        self.assertGreater(result.size[1], result.size[0])

    def test_heic_is_accepted(self):
        try:
            from pillow_heif import from_pillow
        except ImportError:
            self.skipTest("pillow-heif not installed")
        heif = from_pillow(Image.new("RGB", (1500, 1000), (10, 120, 60)))
        out = BytesIO()
        heif.save(out)
        result = self._open(normalize_image(SimpleUploadedFile("IMG_0001.HEIC", out.getvalue())))
        self.assertEqual(result.format, "JPEG")

    def test_non_image_is_rejected_clearly(self):
        with self.assertRaises(InvalidImage):
            normalize_image(SimpleUploadedFile("notes.pdf", b"%PDF-1.4 not an image"))


class MyPhotoUploadTests(TenantTestCase):
    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        self.media = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.media, ignore_errors=True)
        storage = override_settings(
            MEDIA_ROOT=self.media,
            STORAGES={
                "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
                "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
            },
        )
        storage.enable()
        self.addCleanup(storage.disable)
        self.client = TenantClient(self.tenant)
        self.user = User.objects.create_user(phone_number="+254711999001", password="pass12345")
        Membership.objects.create(user=self.user, role=Role.objects.get(name="Member"))
        self.member = Member.objects.create(
            member_number="M-00001", user=self.user, first_name="Mary", last_name="W",
            id_type="NATIONAL_ID", id_number="1", phone_number="+254711999001",
        )
        self.client.force_login(self.user)

    def test_member_uploads_a_huge_photo_and_gets_a_resized_one_back(self):
        upload = SimpleUploadedFile("IMG_20260921.jpg", _image_bytes(size=(6000, 4000)), content_type="image/jpeg")
        response = self.client.post("/api/members/me/photo/", {"photo": upload})
        self.assertEqual(response.status_code, 200, response.content)
        self.assertTrue(response.json()["photo"].startswith("http"))  # absolute URL for the app
        self.member.refresh_from_db()
        with self.member.photo.open("rb") as fh:
            stored = Image.open(fh)
            self.assertEqual((stored.format, max(stored.size)), ("JPEG", 1024))

    def test_non_image_upload_is_a_clear_400(self):
        upload = SimpleUploadedFile("cv.docx", b"PK not an image", content_type="application/octet-stream")
        response = self.client.post("/api/members/me/photo/", {"photo": upload})
        self.assertEqual(response.status_code, 400)
        self.assertIn("image", str(response.json()).lower())
