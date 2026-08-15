from __future__ import annotations

import argparse
import json
import re
import unicodedata
import urllib.parse
import urllib.request
from urllib.error import HTTPError, URLError
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "data"
OUT_DIR = ROOT / "tmp" / "flavor_candidates"

OPENVERSE_API = "https://api.openverse.org/v1/images/"

# Better search quality by expanding with plain flavor words.
QUERY_HINTS = {
    "uva": "grape",
    "jamaica": "hibiscus flower tea",
    "tejuino": "corn drink",
    "chicle": "bubble gum",
    "tamarindo": "tamarind fruit",
    "mango_con_chile": "mango chili",
    "limon_hierbabuena": "lime mint",
    "limon": "lime lemon",
    "mango": "mango fruit",
    "guanabana": "soursop fruit",
    "ciruela_amarilla": "yellow plum fruit",
    "pepino_limon_chia": "cucumber lime chia",
    "frutos_rojos": "mixed berries",
    "panditas": "gummy bears candy",
    "picafresa": "strawberry candy",
    "comegalletas": "cookies and cream",
    "elote": "sweet corn",
    "ferrero": "hazelnut chocolate",
    "mamey": "mamey sapote fruit",
    "mazapan": "peanut candy",
    "nutella": "hazelnut spread",
    "oreo": "cookie sandwich",
    "red_velvet": "red velvet cake",
    "taro": "taro dessert",
    "crema_de_fresas": "strawberry cream",
    "crema_de_mango": "mango cream",
    "crema_de_guayaba": "guava cream",
    "cafe_light": "coffee",
    "coco_light": "coconut",
    "hierbabuena_light": "mint",
    "nuez_light": "walnut",
    "vainilla_light": "vanilla",
}


def _strip_prefix(name: str) -> str:
    prefixes = [
        "Boli Regular - ",
        "Boli Light - ",
        "Nieve AGUA - ",
        "Nieve LECHE - ",
        "Nieve CREMA - ",
        "Nieve LIGHT - ",
    ]
    for prefix in prefixes:
        if name.startswith(prefix):
            return name[len(prefix) :].strip()
    return name.strip()


def _slugify(name: str) -> str:
    normalized = unicodedata.normalize("NFKD", name)
    ascii_text = "".join(c for c in normalized if not unicodedata.combining(c))
    ascii_text = ascii_text.lower().strip()
    ascii_text = re.sub(r"[^a-z0-9]+", "_", ascii_text).strip("_")
    return ascii_text


def _collect_flavors() -> list[tuple[str, str]]:
    bolis = json.loads((DATA_DIR / "bolis_modifiers.json").read_text(encoding="utf-8"))
    nieves = json.loads((DATA_DIR / "nieves_modifiers.json").read_text(encoding="utf-8"))
    names: list[str] = []
    for option in bolis["modifierGroups"][0]["options"]:
        names.append(_strip_prefix(option["supplyName"]))
    for option in nieves["flavorOptions"]:
        names.append(_strip_prefix(option["supplyName"]))

    unique: list[tuple[str, str]] = []
    seen: set[str] = set()
    for name in names:
        slug = _slugify(name)
        if slug in seen:
            continue
        seen.add(slug)
        unique.append((name, slug))
    return unique


def _http_get_json(url: str) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "ice-pos-flavor-asset-fetcher/1.0"},
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def _download(url: str, out_path: Path) -> bool:
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "ice-pos-flavor-asset-fetcher/1.0"},
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            data = response.read()
        out_path.write_bytes(data)
        return True
    except Exception:
        return False


def _build_query(name: str, slug: str) -> str:
    hint = QUERY_HINTS.get(slug)
    if hint:
        return f"{name} {hint} icon"
    return f"{name} flavor icon"


def _ascii_name(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(c for c in normalized if not unicodedata.combining(c))


def _query_variants(name: str, slug: str) -> list[str]:
    base_ascii = _ascii_name(name).strip()
    hint = QUERY_HINTS.get(slug, "")
    seed = f"{base_ascii} {hint}".strip()
    variants = [
        f"{seed} icon",
        f"{seed} illustration",
        f"{seed} clipart",
        f"{seed} fruit",
        f"{seed} dessert",
        f"{seed} food",
        base_ascii,
        hint,
        f"{slug.replace('_', ' ')} icon",
    ]
    dedup: list[str] = []
    seen: set[str] = set()
    for v in variants:
        q = re.sub(r"\s+", " ", v).strip()
        if not q:
            continue
        k = q.casefold()
        if k in seen:
            continue
        seen.add(k)
        dedup.append(q)
    return dedup


def fetch_candidates(max_per_flavor: int = 6, only_slugs: set[str] | None = None) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    flavor_rows = _collect_flavors()
    summary: dict[str, Any] = {"flavors": []}

    for flavor_name, slug in flavor_rows:
        if only_slugs and slug not in only_slugs:
            continue
        flavor_dir = OUT_DIR / slug
        flavor_dir.mkdir(parents=True, exist_ok=True)
        # clean previous run files to avoid stale picks
        for old in flavor_dir.glob("*"):
            if old.is_file():
                old.unlink()

        kept: list[dict[str, Any]] = []
        seen_urls: set[str] = set()
        query_used: list[str] = []

        for query in _query_variants(flavor_name, slug):
            if len(kept) >= max_per_flavor:
                break
            query_used.append(query)
            for page in (1, 2):
                if len(kept) >= max_per_flavor:
                    break
                params = urllib.parse.urlencode(
                    {
                        "q": query,
                        "page_size": max_per_flavor,
                        "page": page,
                    }
                )
                url = f"{OPENVERSE_API}?{params}"
                try:
                    data = _http_get_json(url)
                except (HTTPError, URLError, TimeoutError):
                    continue
                results = data.get("results", [])
                if not results:
                    continue
                for item in results:
                    if len(kept) >= max_per_flavor:
                        break
                    img_url = item.get("url")
                    thumb = item.get("thumbnail")
                    download_url = thumb or img_url
                    if not download_url:
                        continue
                    dedup_key = (img_url or thumb or "").strip()
                    if not dedup_key or dedup_key in seen_urls:
                        continue
                    seen_urls.add(dedup_key)
                    ext = "jpg"
                    low = download_url.lower()
                    for maybe in ("png", "webp", "jpeg", "jpg"):
                        if f".{maybe}" in low:
                            ext = maybe
                            break
                    filename = f"{len(kept) + 1:02d}.{ext}"
                    out_path = flavor_dir / filename
                    ok = _download(download_url, out_path)
                    if not ok and img_url and img_url != download_url:
                        ok = _download(img_url, out_path)
                    if not ok:
                        continue
                    kept.append(
                        {
                            "file": filename,
                            "thumbnail": thumb,
                            "image": img_url,
                            "source": item.get("foreign_landing_url") or item.get("url"),
                            "title": item.get("title"),
                            "creator": item.get("creator"),
                            "license": item.get("license"),
                            "license_version": item.get("license_version"),
                            "provider": "openverse",
                            "query": query,
                        }
                    )

        (flavor_dir / "index.json").write_text(
            json.dumps(
                {
                    "flavor_name": flavor_name,
                    "slug": slug,
                    "queries": query_used,
                    "candidates": kept,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )

        summary["flavors"].append(
            {
                "flavor_name": flavor_name,
                "slug": slug,
                "count": len(kept),
            }
        )
        print(f"[{slug}] downloaded {len(kept)} candidates")

    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nDone. Review folders in: {OUT_DIR}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download flavor image candidates from Openverse.")
    parser.add_argument("--max", type=int, default=6, help="Max candidates per flavor.")
    parser.add_argument(
        "--only",
        type=str,
        default="",
        help="Comma-separated slugs to process, e.g. uva,jamaica,tamarindo",
    )
    args = parser.parse_args()
    only = {s.strip() for s in args.only.split(",") if s.strip()} if args.only else None
    fetch_candidates(max_per_flavor=max(1, args.max), only_slugs=only)
