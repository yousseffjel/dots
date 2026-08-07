# Plan — picom-perf-tuning

## Goal
Epic sub-task 10. Tune picom for "max performance": shadows off,
`unredir-if-possible` on, drop options that cost work and buy nothing. Base
config and .dcol template must carry identical settings or the first wallpaper
change silently reverts the tuning — so add a test proving it.

## Scope
- config/picom/picom.conf, config/theme/templates/always/picom.dcol
- tests/picom-lockstep.sh, docs/THEMING.md

## Allowed
- config/picom/picom.conf, config/theme/templates/always/picom.dcol
- tests/picom-lockstep.sh, docs/THEMING.md
- .github/workflows/ci.yml (added mid-task, user-approved — see Deviations)

## Forbidden
- scripts/theme/reload.sh (reload_picom stays — template is kept)
- scripts/theme/apply-templates.sh, scripts/symlinks.sh
- suckless/, config/thunar/, config/dunst/, packages/

## Steps
1. Tune `picom.conf`: `shadow = false` + remove the six dead shadow options,
   `unredir-if-possible = true`, drop `detect-rounded-corners`, trim `wintypes`.
2. Mirror identical settings into `picom.dcol`, dropping its now-unused
   `<wallbash_pry1>` placeholder.
3. `tests/picom-lockstep.sh`: run apply-templates.sh against the static palette
   in a sandbox, diff output vs picom.conf ignoring comments/blanks.
4. Update `docs/THEMING.md` — picom now has no wallpaper-derived content.
5. Verify: lockstep test, lint, libconfig syntax sanity on both files.
6. (added) CI `tests` job running every dependency-free `tests/*.sh`.

## Out of scope
- Deleting picom.dcol (user chose to keep it placeholder-less).
- `xrender-sync-fence` — NVIDIA-only; target is Intel UHD 770/i915.

## Risks
- The two files drifting — step 3 makes that a test failure.
- picom cannot be launched here (starting it would composite on the live
  desktop) — checked statically instead.
