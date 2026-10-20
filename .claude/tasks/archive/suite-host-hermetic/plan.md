# Plan — suite-host-hermetic

## Goal
The suite passes on a dev host that has autorandr and /usr/share/themes/Adwaita-dark
(it failed 2 checks on the Arch host, green in CI), and `--help` of install-void.sh
and symlinks.sh prints the whole header instead of a fixed, truncated line range.

## Scope
- tests/dwm-display.sh
- tests/wallpaper-follows-display.sh
- tests/lib/doctor-sandbox.sh
- tests/help-header.sh
- scripts/install-void.sh
- scripts/symlinks.sh
- CHANGELOG.md

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. dwm-display.sh + wallpaper-follows-display.sh: sealed PATH (tests/lib/sealed-path.sh), so removing the fake autorandr means NO autorandr
2. doctor-sandbox.sh run_doctor: XDG_DATA_DIRS pointed at an empty sandbox dir (env -i left it unset → /usr/share)
3. install-void.sh + symlinks.sh --help: header up to the first non-comment line (install-live.sh's idiom)
4. tests/help-header.sh: --help == the header comment block, sandboxed HOME + all four XDG vars; no `sed -n '2,Np'` left in scripts/
5. Mutants (on copies): unseal PATH, drop XDG_DATA_DIRS, restore a fixed range — each must be caught; full suite green on this host
6. CHANGELOG [Unreleased] line

## Out of scope
- Records cleanup (14-day archive sweep, CURRENT_AUDIT.md rotation): protocol puts it on main, done at the post-merge fold
- apply-templates.sh INT trap (cosmetic, logged 2026-10-19)

## Risks
- Sealed PATH misses a tool dwm-display needs → script fails for a reason that looks like its bug — seal_path fails loudly; run each test before/after
- --help prints historical header notes — accepted: that is what the header is
