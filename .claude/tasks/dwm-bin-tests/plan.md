# Plan — dwm-bin-tests

## Goal
Close the zero-coverage gap on `config/dwm/bin/*`. Epic scope-c showed the cost:
a total failure shipped green because nothing in `tests/` runs those scripts.

## Scope
- tests/dwm-*.sh
- TESTING.md
- CLAUDE.md

## Allowed

## Forbidden
- config/dwm/bin/
- config/sxhkd/sxhkdrc

## Steps
1. `tests/dwm-colorpicker.sh` — hex across PNG32/RGBA, PNG24/RGB, PNG48/16-bit,
   PNG8/palette, all 6 digits; plus the four failure paths.
2. Mutant it: drop `-alpha off -depth 8` from a COPY; the test must fail.
3. `tests/dwm-display.sh` — disconnected excluded, single-monitor offers no
   extend/mirror, autorandr first, one xrandr call per preset, Escape exits 0.
4. Mutant it too — one keeping the menu right but breaking a command.
5. TESTING.md entries for both.
6. CLAUDE.md's `tests/` enumeration (it appears TWICE).
7. Full suite + `tests/lint.sh --strict`.

## Out of scope
- Editing the two scripts (Forbidden); the other seven `dwm-*` scripts.

## Risks
- **Shim fidelity is the whole point.** A shim must emit the REAL tool's output
  format — an RGB fake for RGBA maim is exactly what hid the last bug.
- **`xclip` MUST be shimmed** or the test clobbers the real clipboard.
- CI's `tests` job is ubuntu-latest, bash + coreutils only. dwm-display needs
  nothing more; dwm-colorpicker needs REAL ImageMagick and must skip **loudly**
  when it is absent, never silently pass.
- Never invoke `sxhkd` (no parse-check mode — it grabs keys) or `udiskie`
  (`--automount` mounts real devices).
- 250-line cap: two files, not one, per the fastfetch/starship precedent.
