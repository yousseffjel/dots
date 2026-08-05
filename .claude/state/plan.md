# Plan — theming-colorgen

## Goal
`scripts/theme/colorgen.sh <wallpaper>` — ImageMagick-only, dark-mode-only
color extraction producing a HyDE-wallbash-compatible `colors.dcol`
palette (dcol_pry1-4, dcol_txt1-4, dcol_1xa1..dcol_4xa9, `_rgba` variants),
cached by wallpaper path+mtime hash.

## Scope
- scripts/theme/colorgen.sh

## Allowed
- scripts/theme/

## Forbidden
- HyDE/ (read-only research reference during development; the script
  itself never references it — see rule 9)

## Steps
1. Extract N=4 dominant colors via `magick -kmeans` + histogram (fuzz 70%),
   sorted by pixel count — reimplements wallbash.sh's own extraction step,
   verified against HyDE/Configs/.local/lib/hyde/wallbash.sh for algorithm
   fidelity (read-only reference, not copied verbatim)
2. Sort the 4 candidates by real perceptual luminance ascending (a
   correctness improvement over upstream's hex-lexicographic sort — see
   script header comment) -> dcol_pry1 (darkest) .. dcol_pry4 (lightest)
3. Enforce dark-mode floor on dcol_pry1 (darken via -modulate loop if over
   threshold) — hardcoded dark, no light-mode branch
4. Per-primary: text color (invert + brightness-modulate, matching
   upstream's own approach) with a light-gray safety fallback; 9 accent
   shades via HSB hue-locked brightness/saturation curve (upstream's
   default "dark" profile curve, hardcoded — no vibrant/pastel/mono/custom
   profile flags, out of scope)
5. Cache: sha256(realpath+mtime) key stored alongside colors.dcol; skip
   regeneration on cache hit unless --force

## Out of scope
- Video wallpapers / ffmpeg thumbnail extraction (upstream supports this;
  spec only asks for `<wallpaper>` — static images)
- vibrant/pastel/mono/custom color-curve profiles (upstream flag-selectable;
  spec asks for dark-mode-only, single curve)
- HyDE's parameterized `_rgba(\1)` sed-backreference trick — plain
  "R,G,B,A" (A=255) instead, since the template engine (sub-task 3) wasn't
  asked to support parameterized alpha capture

## Risks
- ImageMagick version differences (this repo targets Fedora's dnf-packaged
  ImageMagick) — mitigated: tested the exact pipeline (kmeans, histogram
  sed parsing, HSB hue extraction, hsb() color spec, modulate darkening)
  against a real synthetic test image with this sandbox's IM 7.1.2-26
  before writing the script
- Solid-color / low-color-count wallpapers — mitigated: retry with more
  kmeans clusters, then pad by generating brightness-shifted variants if
  still short of 4 (matches upstream's own regen-missing-color fallback)
