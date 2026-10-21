# palette-missing-keys
Date: 2026-10-21
Files: 5 | Lines: +~170/-5

## What changed
- `scripts/theme/apply-templates.sh`: `palette_gaps` lists the placeholders the selected template groups use that the palette does not define (placeholders grepped from the templates, keys read back from the parser's own sed script, `comm -23`). Any gap: refused before a single write or post-command, naming the keys. New `--check` stops after that test.
- `scripts/theme/theme-apply.sh`: runs `apply-templates.sh --check` before `apply_identity` and `wallpaper-default.sh`, which run ahead of the templates.
- New `tests/palette-complete.sh` (throwaway copy; every post-command replaced by a marker, reload.sh/wallpaper-default.sh stubbed, fake pkill/xrdb/setsid/notify-send/feh, no DISPLAY).
- `docs/THEMING.md` § Adding a theme; CHANGELOG [Unreleased] Fixed.

## Why
VM edge-case pass: a theme whose colors.dcol lacked dcol_pry1/dcol_txt1 (+_rgba) was applied with exit 0. Eight rendered files kept `<wallbash_pry1>`/`<wallbash_txt1>`; xresources got `dwm.normbgcolor: #<wallbash_pry1>`; on reload dwm re-exec'd and died in drw_clr_create (suckless/dwm/drw.c:178), ~/.xinitrc ended and ly logged the session out (ly.log 11:42:38). The broken cache would have killed the next login too (xinitrc merges it before dwm). The engine already treats themes as possibly third-party (it parses rather than sources them) but never checked completeness.

## Assumptions
- Type B: the engine, not dwm, is the gate. A dwm fallback colour would mean changing vendored drw.c plus a patch record, and would leave dmenu/st/the other targets with garbage; out of scope.
- Type B: a gap anywhere in the selected groups refuses the whole apply, even when that template's app is not installed (its target dir missing): the theme is incomplete either way.

## Test coverage
- Test failed before the fix (every refusal check); passes after.
- Mutants on a tar copy: gate only under --check; theme-apply pre-check removed; comm sides swapped; placeholder regex without digits — all caught.
- Reviewer WARN (group selection untested, theme/ is empty) → added a theme/ template in the copy: `all` refuses its gap, `always` ignores it.
- VM, headless: theme-apply and apply-templates both exit 1 naming `pry1 txt1`; cache/config hashes unchanged; the four shipped palettes and the live wallbash cache pass --check.
- lint passed; full suite 101 OK.

## Incident during testing
- The reproducing run ended the VM's X session (that is the bug). The cache was repaired headless with `dots theme --wallbash` (no placeholders left) before anyone logs in again.
- A malformed command of mine piped a tar stream into the VM's `bash -s`; it ran two lines that failed harmlessly ("No such file", "command not found") and stopped at a syntax error on line 3. Nothing changed.

## Follow-ups
- Re-login at ly on the VM to confirm the repaired session starts and the refusal leaves a live dwm running.
