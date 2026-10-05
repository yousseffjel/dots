# themes/dark/wallpapers

Intentionally empty. No wallpapers are committed to this repository —
they are large binaries, and most attractive ones carry licences that
make redistribution a question rather than a given.

Since 2026-10-05 a fresh install is not left on a black screen because of
it: `scripts/theme/wallpaper-default.sh` renders a gradient from the active
theme's palette whenever no wallpaper of your own is set (see
`docs/THEMING.md`, "The generated default wallpaper").

## Where wallpapers actually go

`scripts/theme/wallpaper.sh` reads from `~/Pictures/wallpapers` by
default. Override with `DOTS_WALLPAPER_DIR`:

```sh
export DOTS_WALLPAPER_DIR="$HOME/media/walls"
```

Recognised formats: `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp` — the set
`feh` can set as a background.

## Using this directory instead

If you would rather keep wallpapers alongside the theme, drop them here
and point the variable at it:

```sh
DOTS_WALLPAPER_DIR=themes/dark/wallpapers scripts/theme/wallpaper.sh --select
```

They will be picked up but remain untracked unless you deliberately
`git add` them — consider whether you have the right to redistribute an
image before committing it to a public repo.

## Note on the static theme

`themes/dark/` is a *static* palette: `theme-apply.sh dark` uses
`colors.dcol` and ignores the wallpaper entirely. Wallpapers only matter
for `wallpaper.sh` and `theme-apply.sh --wallbash`, which derive colours
from the image itself.
