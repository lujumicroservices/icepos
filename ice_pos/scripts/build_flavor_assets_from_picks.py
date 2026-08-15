from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
PICKS_FILE = ROOT / "tmp" / "flavor_candidates" / "picks.json"
OUT_DIR = ROOT / "assets" / "images" / "flavors"
LICENSE_REPORT = ROOT / "assets" / "images" / "flavors" / "ASSET_LICENSES.json"


def _load_picks() -> list[dict]:
    if not PICKS_FILE.exists():
        raise FileNotFoundError(
            f"Missing {PICKS_FILE}. Create it with a list of picked images.\n"
            "Example row:\n"
            '{ "slug": "mango", "source_file": "tmp/flavor_candidates/mango/01.jpg", '
            '"source_url": "https://...", "license": "cc0", "creator": "..." }'
        )
    data = json.loads(PICKS_FILE.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("picks.json must be a JSON array.")
    return data


def _render_asset(source_path: Path, out_path: Path) -> None:
    with Image.open(source_path) as img:
        img = img.convert("RGB")
        # Center crop to square and normalize to app tile size.
        square = ImageOps.fit(img, (256, 256), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
        square.save(out_path, format="PNG", optimize=True)


def main() -> None:
    picks = _load_picks()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    report: list[dict] = []
    generated = 0
    for row in picks:
        slug = row.get("slug")
        source_file = row.get("source_file")
        if not slug or not source_file:
            print(f"Skipping invalid row: {row}")
            continue

        src = ROOT / source_file
        if not src.exists():
            print(f"Source not found for {slug}: {src}")
            continue

        out = OUT_DIR / f"{slug}.png"
        _render_asset(src, out)
        generated += 1

        report.append(
            {
                "slug": slug,
                "output_file": str(out.relative_to(ROOT)).replace("\\", "/"),
                "source_file": source_file,
                "source_url": row.get("source_url"),
                "license": row.get("license"),
                "creator": row.get("creator"),
                "notes": row.get("notes"),
            }
        )
        print(f"[ok] {slug} -> {out.name}")

    LICENSE_REPORT.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nGenerated {generated} assets into {OUT_DIR}")
    print(f"License report: {LICENSE_REPORT}")


if __name__ == "__main__":
    main()
