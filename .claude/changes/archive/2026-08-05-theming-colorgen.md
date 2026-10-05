# theming-colorgen
Date: 2026-08-05
Files: 1 (scripts/theme/colorgen.sh, new) | Lines: +235

## What changed
- Added `scripts/theme/colorgen.sh <wallpaper> [--force]` — sub-task 2/7
  of the theming-engine Epic. ImageMagick-only, dark-mode-only color
  extraction producing a HyDE-wallbash-compatible `colors.dcol` palette
  at `~/.cache/dots/theme/colors.dcol`: `dcol_mode="dark"`, 4 primaries
  (`dcol_pry1..4`, sorted darkest -> lightest by real perceptual
  luminance), 4 text colors (`dcol_txt1..4`), 9 accent shades per
  primary (`dcol_NxaJ`, N=1-4 J=1-9), and a plain `"R,G,B,255"` `_rgba`
  sibling for every color above.
- Cached by `sha256(realpath(wallpaper):mtime)`, stored as a leading
  comment line in the same `colors.dcol` file — re-running on an
  unchanged wallpaper is a no-op (`--force` overrides).
- Extraction pipeline: `magick -kmeans` + histogram (fuzz 70%, matching
  upstream), retried with more clusters if the wallpaper doesn't yield 4
  distinct colors, padded with brightness-shifted variants of the last
  candidate as a last resort (e.g. a solid-color wallpaper).
- Dark-mode floor: `dcol_pry1`'s luminance is checked against a 0.35
  threshold; if over, it's darkened in a bounded loop (max 4 passes,
  60% brightness each) until under threshold — guarantees "never ship
  a light background" even for an all-white input. Verified live
  against a synthetic light-gray/white test image (see Test coverage).
- Text colors: invert the primary's RGB, brightness-modulate (matching
  upstream's `188,10,100` constant), then a safety floor beyond
  upstream — force a known-readable `#E8E8E8` if the derived color's
  luminance still isn't light enough.
- Accent shades: extract the primary's HSB hue, then walk upstream
  wallbash.sh's own default "dark" brightness/saturation curve (9 fixed
  steps, `32 50` .. `100 20`) building each shade as `hsb(hue,sat%,bri%)`
  — same hue as the primary, ramped dark to light. Falls back to a
  desaturated flat curve when the wallpaper's HSL saturation mean is
  below 0.12 (near-monochrome), matching upstream's own grey-check.

## Why
Sub-task 2 of `.claude/tasks/scope-a-theming-engine.md` — the color
extraction step between "wallpaper" and "template engine" in the
architecture the user asked for (wallpaper -> ImageMagick -> colors.dcol
-> templates -> targets -> reload). Read HyDE-Project/HyDE's own
`wallbash.sh` (local untracked reference clone, see CLAUDE.md rule 9) as
a design reference during development to get the dcol naming, HSB accent
curve, and text-color derivation right — this script never sources,
symlinks, or shells out to anything under `HyDE/` at runtime; the
algorithm was re-typed and adapted, not copied.

## Assumptions
- **Type B** — `_rgba` ships as a plain `"R,G,B,255"` tuple, not
  upstream's parameterized `"rgba(R,G,B,\1)"` sed-backreference template
  (which lets a `.dcol` template author pick any alpha at substitution
  time via `<wallbash_pryN_rgba(0.8)>`). Alternative considered: replicate
  the parameterized form for exact upstream fidelity — rejected because
  the user's Part 3 template-engine spec (`target_path|post_command`
  header + flat `<wallbash_NAME>` substitution) never asked for
  parameterized placeholders, and building matching engine support for a
  feature nothing requested would be scope creep. If incorrect: add the
  sed-backreference form to `rgba_line()` and teach `apply-templates.sh`
  (sub-task 3) the `<wallbash_..._rgba(N)>` capture-group syntax.
- **Type B** — dropped upstream's light/vibrant/pastel/mono/`--custom`
  color-curve profile flags; one fixed dark-mode curve only. Matches the
  user's explicit "dark-mode-only" spec — not really a judgment call, but
  recorded since it's a real behavioral gap vs. the reference script.
- **Type C** — no `SCRIPT_DIR`/`DOTS_DIR` boilerplate (repo convention,
  rule 3) — this script has zero repo-relative file references (only a
  user-supplied wallpaper path and `$XDG_CACHE_HOME`), so the pattern's
  purpose doesn't apply here.

## Test coverage
- No test suite for shell scripts in this repo (per `TESTING.md` /
  `tests/lint.sh` scope) — verification is `shellcheck` (clean) +
  `shfmt -i 4 -ci -bn -d` (clean, matches repo formatting) + live
  functional runs against synthetic ImageMagick-generated test images:
  - A 4-color test wallpaper (dark navy + light pink + light blue +
    light green) -> correct luminance-ascending sort, correct dark-floor
    skip (pry1 already dark, no darkening triggered), 90-line well-formed
    `colors.dcol`, all values `source`-able.
  - A monochrome light-gray/white test wallpaper -> dark-floor loop
    correctly triggered twice (CCCCCC -> 7A7A7A -> 494949, converging
    under the 0.35 threshold) and the near-monochrome desaturated accent
    curve correctly selected.
  - Cache-hit path (unchanged wallpaper, no `--force`) -> instant exit,
    no regeneration.
  - Error paths: no wallpaper arg, missing wallpaper file -> both exit 1
    with a clear message.
- Reviewer subagent (two passes) independently re-ran the same class of
  live verification plus its own synthetic-image test; first pass BLOCKed
  on the file exceeding the repo's 250-line cap (256 lines), second pass
  (after trimming the header comment to 235 lines, no logic change)
  returned READY.

## Follow-ups
- Sub-task 3 (`apply-templates.sh`) consumes exactly the `dcol_*` key
  names this script produces — no further changes expected here unless
  the template engine turns out to need the parameterized `_rgba` form
  noted above.
- `colors.dcol`'s single-file-holds-everything design (vs. HyDE's
  per-wallpaper-hash cache directory) means only the most recently
  generated wallpaper's palette is ever cached — acceptable per the
  spec ("cache keyed on wallpaper path+mtime hash for instant re-apply"
  describes freshness, not a multi-wallpaper history), but worth knowing
  if a future "recent wallpapers" picker is ever wanted.
