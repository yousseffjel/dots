# suite-host-hermetic
Date: 2026-10-20
Files: 7 + 1 new | Lines: +52/-17, plus tests/help-header.sh (106)

## What changed
- `tests/dwm-display.sh`, `tests/wallpaper-follows-display.sh`: dwm-display runs under a
  sealed PATH (`seal_path "$TMP/bin" bash awk grep cat`), not `"$TMP/bin:$PATH"`. Removing
  the fake autorandr now means no autorandr at all.
- `tests/wallpaper-follows-display.sh`: dropped `chmod 755 "$TMP/bin"/*`. With sealed links
  in that dir it chmod-ed the REAL /usr/bin tools through them, stopped only by file
  permissions (the hazard in memory `sealed-path-copies-are-symlinks`). The line above it
  already chmods both fakes.
- `tests/lib/doctor-sandbox.sh` `run_doctor`: `XDG_DATA_DIRS="$SB/share"` (an empty dir).
  `env -i` left it unset, so `check_gtk3_theme` defaulted to /usr/share.
- `scripts/install-void.sh`, `scripts/symlinks.sh`: `--help` prints the header up to its first
  non-comment line (`sed -n '2,/^[^#]/{/^#/s/^# \{0,1\}//p}'`, install-live.sh's idiom), not
  `2,50p` / `2,15p`. install-void.sh handles `-h|--help` BEFORE the install.log tee; the
  branch in the main argument loop is gone.
- New `tests/help-header.sh`: every whole-header script's `--help` equals the header as the
  test reads it independently (sandboxed HOME + four XDG vars); install-void.sh `--help`
  leaves install.log unchanged; every remaining fixed range `sed -n 'A,Bp'
  "${BASH_SOURCE[0]}"` in scripts/ ends at a paragraph break.
- CHANGELOG [Unreleased]: two Fixed lines.

## Why
The 2026-10-20 status check ran the suite on the Arch dev host: 92 OK, 2 FAILED, while CI
was green on the same commit (784d203). Both failures were tests reaching the host rather
than their fakes. `dwm-display.sh`'s Escape case logged `xrandr -q --verbose`, which was
the real `/usr/bin/autorandr` calling the fake xrandr. `doctor.sh`'s "an Adwaita-dark nothing
provides warns" found `/usr/share/themes/Adwaita-dark`. The first also hid a false pass:
"degrades cleanly when autorandr is not installed" passed on this host only because no
real profiles are saved. The `--help` item was the nsxiv-package log's unchecked follow-up.
Correction to what I told the user at the status check: install-void.sh's old `2,50p` ended
at a paragraph end and dropped the later paragraphs (cursor theme, clipmenu). It was
symlinks.sh's `2,15p` that cut off mid-sentence.

## Assumptions
- Type B: the four other fixed-range help printers (update.sh, wallpaper.sh,
  theme-apply.sh, ly-theme.sh) are deliberate usage excerpts and were kept. The test holds
  each to a paragraph end instead of forbidding fixed ranges. If they should print whole
  headers too, switch them to the idiom and help-header.sh picks them up by its grep.
- Type B: `install-void.sh --help` now prints its whole 56-line header, history notes
  (lazygit, Bibata, clipmenu) included. That is the header as written.
- Records cleanup (14-day archive sweep, CURRENT_AUDIT.md rotation), asked for in the same
  request, is deliberately NOT in this slot. session-protocol.md puts both on main, to run
  at the post-merge fold.

## Test coverage
- `tests/run-tests.sh` in the slot on the Arch host: 95 OK, 0 failed (was 92 + 2 FAILED).
  `tests/lint.sh`: passed (shellcheck, shfmt, markdownlint).
- Mutants, run on tar copies of the worktree in the scratchpad: 6/6 caught.
  - Unseal dwm-display (M1): "Escape applied something: xrandr -q --verbose".
  - Drop XDG_DATA_DIRS (M2): "an Adwaita-dark nothing provides warns".
  - symlinks.sh back to `2,15p` (M3): the whole-header count AND "line 15 ends a paragraph".
  - install-void.sh back to `2,50p` (M4): the whole-header count only.
  - Tee before the help loop (M5b): "install.log unchanged". The first M5 put the tee after
    the loop, which is not a real mutant; it survived and was redone.
  - Header strip removed from the test (M6): "--help is the full header".
- Not caught: unsealing `wallpaper-follows-display.sh` passes on this host. Its seal is
  defensive; no host failure was seen there.
- Reviewer: READY.

## Follow-ups
- On main, post-merge: fold this log into CURRENT_AUDIT.md, run the 14-day archive sweep
  (the 2026-10-05 logs; 10-06 is exactly 14 days old), and rotate CURRENT_AUDIT.md (2521 lines, cap 250).
- The status check's `install-void.sh --help` in the main checkout appended two lines to
  the gitignored `install.log` there; left for the user to decide.
