# Flavor Asset Pipeline (Web Search + Curation)

This workflow lets you search flavor image candidates from the web, manually choose favorites, and build final normalized assets for the POS modifier grid.

## 1) Download candidates from Openverse

```powershell
python scripts/search_flavor_image_candidates.py
```

Outputs:

- `tmp/flavor_candidates/<slug>/NN.ext` candidate images
- `tmp/flavor_candidates/<slug>/index.json` candidate metadata
- `tmp/flavor_candidates/summary.json`

## 2) Pick one image per flavor

Create `tmp/flavor_candidates/picks.json` with rows like:

```json
[
  {
    "slug": "mango",
    "source_file": "tmp/flavor_candidates/mango/01.jpg",
    "source_url": "https://openverse.org/image/...",
    "license": "cc0",
    "creator": "Author Name",
    "notes": "bright icon, clear shape"
  }
]
```

`slug` must match the flavor slug used by the app (`assets/images/flavors/<slug>.png`).

## 3) Build final app assets

Requires Pillow:

```powershell
python -m pip install pillow
python scripts/build_flavor_assets_from_picks.py
```

Outputs:

- Final images in `assets/images/flavors/`
- Attribution/license manifest in `assets/images/flavors/ASSET_LICENSES.json`

## 4) Run app

```powershell
flutter pub get
flutter run
```

The modifier grid already resolves image path as:

`assets/images/flavors/<normalized_flavor_name>.png`
