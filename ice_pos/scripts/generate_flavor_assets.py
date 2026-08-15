from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "data"
OUT_DIR = ROOT / "assets" / "images" / "flavors"


def strip_prefix(name: str) -> str:
    prefixes = [
        "Boli Regular - ",
        "Boli Light - ",
        "Nieve AGUA - ",
        "Nieve LECHE - ",
        "Nieve CREMA - ",
        "Nieve LIGHT - ",
    ]
    for p in prefixes:
        if name.startswith(p):
            return name[len(p) :].strip()
    return name.strip()


def slugify(name: str) -> str:
    normalized = unicodedata.normalize("NFKD", name)
    ascii_text = "".join(c for c in normalized if not unicodedata.combining(c))
    ascii_text = ascii_text.lower().strip()
    ascii_text = re.sub(r"[^a-z0-9]+", "_", ascii_text).strip("_")
    return ascii_text


def pick_color(key: str) -> tuple[int, int, int]:
    palette = [
        (233, 78, 119),
        (255, 153, 51),
        (116, 185, 255),
        (88, 177, 159),
        (170, 127, 255),
        (112, 83, 66),
        (242, 201, 76),
        (107, 181, 93),
        (239, 122, 146),
        (67, 153, 190),
        (140, 109, 184),
        (211, 98, 71),
    ]
    h = abs(hash(key))
    return palette[h % len(palette)]


def draw_icon(flavor_name: str, slug: str) -> None:
    size = 256
    img = Image.new("RGBA", (size, size), (245, 247, 250, 255))
    draw = ImageDraw.Draw(img)

    color = pick_color(slug)
    darker = tuple(max(0, c - 30) for c in color)

    # Background circle
    draw.ellipse((24, 24, size - 24, size - 24), fill=(*color, 255), outline=(*darker, 255), width=6)

    # Ice pop shape
    pop_top = (88, 58, 168, 178)
    draw.rounded_rectangle(pop_top, radius=28, fill=(255, 255, 255, 230))
    draw.rectangle((120, 178, 136, 220), fill=(255, 232, 189, 255))
    draw.rounded_rectangle((112, 216, 144, 236), radius=8, fill=(231, 180, 120, 255))

    # Flavor initials
    words = [w for w in re.split(r"\s+", flavor_name.strip()) if w]
    initials = "".join(w[0].upper() for w in words[:2]) or "S"
    try:
        font = ImageFont.truetype("arial.ttf", 54)
    except OSError:
        font = ImageFont.load_default()

    text_bbox = draw.textbbox((0, 0), initials, font=font)
    tw = text_bbox[2] - text_bbox[0]
    th = text_bbox[3] - text_bbox[1]
    draw.text(((size - tw) / 2, 96 - th / 2), initials, fill=(48, 57, 82, 255), font=font)

    # Bottom flavor label
    label = flavor_name[:22]
    try:
        label_font = ImageFont.truetype("arial.ttf", 20)
    except OSError:
        label_font = ImageFont.load_default()
    lb = draw.textbbox((0, 0), label, font=label_font)
    lw = lb[2] - lb[0]
    draw.text(((size - lw) / 2, 238 - (lb[3] - lb[1])), label, fill=(56, 56, 56, 255), font=label_font)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(OUT_DIR / f"{slug}.png", format="PNG")


def collect_unique_flavors() -> list[str]:
    bolis = json.loads((DATA_DIR / "bolis_modifiers.json").read_text(encoding="utf-8"))
    nieves = json.loads((DATA_DIR / "nieves_modifiers.json").read_text(encoding="utf-8"))

    names: list[str] = []
    for option in bolis["modifierGroups"][0]["options"]:
        names.append(strip_prefix(option["supplyName"]))
    for option in nieves["flavorOptions"]:
        names.append(strip_prefix(option["supplyName"]))

    unique: list[str] = []
    seen: set[str] = set()
    for n in names:
        key = n.casefold()
        if key not in seen:
            seen.add(key)
            unique.append(n)
    return unique


def main() -> None:
    flavors = collect_unique_flavors()
    for flavor in flavors:
        draw_icon(flavor, slugify(flavor))
    print(f"Generated {len(flavors)} flavor assets in {OUT_DIR}")


if __name__ == "__main__":
    main()
