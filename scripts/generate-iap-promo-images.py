#!/usr/bin/env python3
"""Generate distinct 1024×1024 IAP promotional images for App Store Connect."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IAP_DIR = ROOT / "docs" / "app-store" / "iap"
LIFETIME_PATH = IAP_DIR / "route_premium_lifetime-1024.png"
MONTHLY_PATH = IAP_DIR / "route_premium_monthly-1024.png"
SIZE = 1024


def make_variant(base: Image.Image, label: str, sublabel: str, accent_rgb: tuple[int, int, int]) -> Image.Image:
    img = base.convert("RGBA").copy()
    draw = ImageDraw.Draw(img)
    banner_h = 220
    overlay = Image.new("RGBA", (SIZE, banner_h), accent_rgb + (230,))
    img.paste(overlay, (0, SIZE - banner_h), overlay)
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 92)
        sub_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 44)
    except OSError:
        title_font = ImageFont.load_default()
        sub_font = ImageFont.load_default()
    draw.text((SIZE // 2, SIZE - banner_h + 52), label, fill="white", font=title_font, anchor="mm")
    draw.text((SIZE // 2, SIZE - banner_h + 148), sublabel, fill=(255, 255, 255, 230), font=sub_font, anchor="mm")
    return img.convert("RGB")


def main() -> None:
    IAP_DIR.mkdir(parents=True, exist_ok=True)
    if not LIFETIME_PATH.exists():
        raise SystemExit(f"Missing base image: {LIFETIME_PATH}")

    base = Image.open(LIFETIME_PATH)
    make_variant(base, "Lifetime", "One-time purchase", (24, 88, 140)).save(LIFETIME_PATH, quality=95)
    make_variant(base, "Monthly", "Auto-renewable subscription", (196, 88, 24)).save(MONTHLY_PATH, quality=95)
    print(f"Wrote {LIFETIME_PATH}")
    print(f"Wrote {MONTHLY_PATH}")


if __name__ == "__main__":
    main()
