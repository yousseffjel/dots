# dwm-bin-tests
Date: 2026-08-12
Files: 9 | Lines: +661/-5

## What changed

- **`tests/dwm-colorpicker.sh`** (206 lines, 12 assertions) — feeds the picker a
  one-pixel image in each PNG format maim might emit (RGBA, RGB, 16-bit,
  palette) and requires six hex digits from all four; pins that `-alpha off`
  **discards** alpha rather than compositing; checks all four failure paths name
  themselves; and checks `--no-notify` still succeeds, so "unknown option is
  rejected" cannot pass for the wrong reason.
- **`tests/dwm-display.sh`** (228 lines, 20 assertions) — disconnected outputs
  excluded, every expected menu entry present, `only X` disabling the others in
  **one** xrandr call, `--primary` set on the only/extend/mirror presets, a
  single monitor offering exactly one entry, autorandr profiles listed first and
  absent cleanly, selection running exactly that entry's command, Escape exiting
  0 having applied nothing, and no connected outputs failing loudly.
- **Suite 10 -> 12.** Both are picked up by CI's `tests/*.sh` glob with no
  workflow change. `TESTING.md` and `CLAUDE.md`'s two `tests/` enumerations updated.
- **Neither script under test was modified** — `## Forbidden` listed
  `config/dwm/bin/`, and both are byte-identical to the starting state.

## Why

Queue item 1, opened by Epic scope-c. `config/dwm/bin/` held **nine scripts and
zero tests**, and sub-task 4 showed exactly what that costs: `dwm-colorpicker`
would have failed on *every* invocation while the full suite stayed green,
because nothing in `tests/` ran it. Only the reviewer caught it.

The two files are split rather than combined for the same reason
`fastfetch-template.sh` and `starship-template.sh` are: together they would be
421 lines, over the 250-line cap. That is necessity, not style.

## Assumptions

- **Type B — ImageMagick is NOT faked.** It is the thing under test; faking it
  would leave the file asserting against its own fixture generator. The
  consequence is a real dependency, so the test **skips loudly** when neither
  `magick` nor `convert` is present — which is what happens in CI's
  ubuntu-latest `tests` job. A silent skip is the green-job-that-checked-nothing
  failure `--strict` was invented for, hence the visible yellow block.
- **Type B — `--list` is the seam for `dwm-display`.** It prints each label with
  the exact command behind it and applies nothing, so the derivation can be
  asserted without a live xrandr. Selection dispatch is tested separately with a
  `dmenu` shim that echoes one label back.
- **Type C — each test defines its own colour helpers** (CLAUDE.md rule 2).
  Neither sources `global_fn.sh`, so the SC2329 exception that applies to
  `tests/manifest-has-path.sh` does not apply here.

## Test coverage

Full suite **12/12, exit 0**, plus `tests/lint.sh --strict`.

**Mutation testing is the actual deliverable here** — a test that cannot fail is
worse than none — so both files were measured against deliberate breakage.
**12 of 13 mutations fail the suite:**

*dwm-colorpicker, 4 of 5:* dropping `-alpha off -depth 8` (the production bug),
dropping either flag alone, and swapping `-alpha off` for the compositing
`-alpha remove`. **Survivor:** loosening `^[0-9A-Fa-f]{6}$` to `{6,8}`. Not
papered over — with normalisation intact, no input tried (RGBA, 16-bit, palette,
grayscale, CMYK) yields anything but six digits, so the strict regex is a second
layer that never fires. Killing it would mean asserting on the script's source
text. Documented in the test header instead.

*dwm-display, 8 of 8:* bare `/connected/` letting a disconnected output through;
`only X` forgetting the others; **labels correct but command wrong**
(`--off` -> `--auto`), which a label-only test would sail past; profiles no
longer first; extend/mirror on a single monitor; Escape treated as an error;
and the two `--primary` drops the reviewer found.

**CI conditions verified directly, not inferred.** On a PATH containing only
bash + coreutils, `dwm-display.sh` passes in full and `dwm-colorpicker.sh` skips
loudly with exit 0.

**Live side effects avoided:** `xclip` and `notify-send` faked (they would
overwrite the real clipboard and post real notifications), `xrandr` faked (it
would reconfigure the tester's displays). The real display was confirmed still
connected afterwards and dunst held PID 2652.

## Follow-ups

- **The reviewer caught a `--primary` gap my own mutants missed, and the reason
  generalises.** Every mutation I wrote targeted behaviour I had just authored
  and was therefore already thinking about; the gap was in a flag I had treated
  as incidental. **Mutation testing only covers the mutations you imagine** —
  which is an argument for the independent gate, not against the technique.
- **ImageMagick 6 is still untested.** The `convert` branch was verified
  *reachable* with a forwarding shim (the test reports "using ImageMagick via
  'convert'" and passes), but only IM7 exists on this host, so IM6's actual
  `%[hex:p{0,0}]` behaviour is unverified. Ubuntu runners have historically
  shipped IM6 — if CI ever installs ImageMagick rather than skipping, that is
  where a surprise would come from.
- **Seven `dwm-*` scripts remain untested**: powermenu, clipmenu, wallpaper,
  theme, screenshot, lock, brightness. The idiom now exists and is proven; each
  is a small, self-contained addition. `dwm-brightness` is the most valuable
  next one — it parses `xrandr --verbose` output and does arithmetic on it,
  which is the same "parse a real tool's output" shape that produced this whole
  thread of bugs.
- Both new files are 206 and 228 lines against a 250 cap; adding cases to either
  will need a split before long.
