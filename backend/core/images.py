"""
Turns any uploaded photo into a small, correctly-rotated JPEG.

Phones produce images Django's ImageField rejects or that are needlessly
huge: iPhone HEIC/HEIF, 12-50 megapixel JPEGs, PNGs with transparency,
photos stored sideways with an EXIF rotation flag. Everything that comes in
as a profile photo or logo goes through normalize_image() instead, so
whatever a member picks, the stored result is a JPEG of at most
MAX_SIDE pixels on its longest side.
"""

from io import BytesIO

from django.core.files.base import ContentFile
from PIL import Image, ImageOps, UnidentifiedImageError

try:  # HEIC/HEIF (iPhone default format) - optional but installed in requirements.
    from pillow_heif import register_heif_opener

    register_heif_opener()
except ImportError:  # pragma: no cover
    pass

MAX_SIDE = 1024
MAX_UPLOAD_BYTES = 25 * 1024 * 1024
JPEG_QUALITY = 85

# Big phone photos are well under this; it only guards against decompression bombs.
Image.MAX_IMAGE_PIXELS = 200_000_000


class InvalidImage(ValueError):
    pass


def normalize_image(uploaded, *, name: str = "photo.jpg", max_side: int = MAX_SIDE) -> ContentFile:
    if uploaded.size and uploaded.size > MAX_UPLOAD_BYTES:
        raise InvalidImage("That image is larger than 25 MB.")
    try:
        uploaded.seek(0)
        image = Image.open(uploaded)
        image.load()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise InvalidImage("That file isn't an image we can read. Try a JPEG, PNG, HEIC or WebP photo.")

    image = ImageOps.exif_transpose(image)  # respect the phone's rotation flag
    if image.mode in ("RGBA", "LA", "P"):
        # JPEG has no transparency: flatten onto white.
        image = image.convert("RGBA")
        background = Image.new("RGB", image.size, (255, 255, 255))
        background.paste(image, mask=image.getchannel("A"))
        image = background
    elif image.mode != "RGB":
        image = image.convert("RGB")

    image.thumbnail((max_side, max_side), Image.LANCZOS)
    out = BytesIO()
    image.save(out, format="JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True)
    return ContentFile(out.getvalue(), name=name)
