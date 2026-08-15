from __future__ import annotations

import re
import shutil
import unicodedata
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_IMAGE = Path(
    r"C:\Users\jvald\.cursor\projects\c-Users-jvald-code-icepos\assets\c__Users_jvald_AppData_Roaming_Cursor_User_workspaceStorage_7cc3d8059888fc944da38782d620e30d_images_ChatGPT_Image_25_abr_2026__10_39_21_p.m.-5e4b38e4-0f8b-485d-a9a1-8e0ce0df0be4.png"
)
OUT_DIR = ROOT / "assets" / "images" / "flavors"
SHEET_COPY = ROOT / "assets" / "images" / "flavor_sheet_reference.png"

# Hand-tuned grid boundaries for this sheet (x: 8 columns, y: 6 rows).
X_EDGES = [8, 129, 249, 372, 502, 633, 755, 884, 1014]
Y_EDGES = [6, 147, 291, 432, 576, 702, 813]

ROWS: list[list[str]] = [
    ["cafe", "coco", "chongos", "chocolate", "rompope", "pistache", "pinon", "vainilla"],
    ["fresa", "nuez", "uva", "jamaica", "tejuino", "limon_hierbabuena", "chicle", "tamarindo"],
    ["mango_con_chile", "limon", "mango", "guanabana", "ciruela_amarilla", "frutos_rojos", "panditas", "picafresa"],
    ["comegalletas", "elote", "ferrero", "mamey", "mazapan", "nutella", "oreo", "red_velvet"],
    ["taro", "crema_de_fresas", "crema_de_mango", "crema_de_guayaba"],
    ["cafe_light", "coco_light", "hierbabuena_light", "nuez_light", "pepino_limon_chia", "vainilla_light"],
]


def _slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_text = "".join(c for c in normalized if not unicodedata.combining(c))
    ascii_text = ascii_text.lower().strip()
    ascii_text = re.sub(r"[^a-z0-9]+", "_", ascii_text).strip("_")
    return ascii_text


def main() -> None:
    if not SOURCE_IMAGE.exists():
        raise FileNotFoundError(f"Source image not found: {SOURCE_IMAGE}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE_IMAGE, SHEET_COPY)

    img = Image.open(SOURCE_IMAGE).convert("RGB")
    generated = 0
    for row_idx, row in enumerate(ROWS):
        y0 = Y_EDGES[row_idx]
        y1 = Y_EDGES[row_idx + 1]
        for col_idx, name in enumerate(row):
            x0 = X_EDGES[col_idx]
            x1 = X_EDGES[col_idx + 1]
            # tiny inset to remove gray card border.
            crop = img.crop((x0 + 2, y0 + 2, x1 - 2, y1 - 2))
            tile = crop.resize((256, 256), Image.Resampling.LANCZOS)
            slug = _slugify(name)
            tile.save(OUT_DIR / f"{slug}.png", format="PNG", optimize=True)
            generated += 1

    print(f"Generated {generated} flavor assets in {OUT_DIR}")
    print(f"Reference sheet copied to {SHEET_COPY}")


if __name__ == "__main__":
    main()
