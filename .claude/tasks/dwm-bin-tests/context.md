# Context — dwm-bin-tests

## Background
Queue item 1, opened by Epic scope-c. `config/dwm/bin/` holds nine scripts and
has **zero** tests. In sub-task 4 that let a total failure ship green: the
reviewer BLOCKED on `dwm-colorpicker` failing on every invocation, and the full
suite had passed the whole time because nothing in `tests/` runs those scripts.

## Prior Decisions
- `.claude/changes/2026-08-12-colorpicker-display.md` — the bug and its fix.
  `%[hex:p{0,0}]` returns **8** digits (RRGGBBAA) for maim's RGBA output and
  **12** for 16-bit; `-alpha off -depth 8` normalises both. The strict
  `^[0-9A-Fa-f]{6}$` check was deliberately KEPT so a format change fails loudly
  rather than truncating a colour. A test must lock all of that in.
- `-alpha off` **discards**; `-alpha remove -background white` **composites** and
  would give a different, wrong colour. The test should pin the discard
  behaviour, since swapping the flags is the plausible future mistake.
- CLAUDE.md rule 2 — each test defines its own colour helpers. Note the
  exception in [[dots-test-sourcing-global-fn-helpers]]: only tests that
  `source global_fn.sh` skip that, and neither of these will.

## References
- `tests/fastfetch-template.sh` and `tests/starship-template.sh` — the idiom to
  copy, including the SAFETY header explaining what is shimmed and why. They
  were split into two files rather than one because of the 250-line cap; the
  same applies here.
- `tests/autostart-daemons.sh` — the best example of a test that RUNS the thing
  rather than parsing it, and of an explicit "things this test does not know
  about" check. `dwm-display`'s menu could use the same shape.
- `.github/workflows/ci.yml` — the `tests` job is **ubuntu-latest, bash +
  coreutils only**, discovered by glob (so a new file is picked up free) and
  does NOT pass `--strict`. Anything needing more must skip cleanly.
- `config/dwm/bin/dwm-colorpicker:88-100` — the ImageMagick call under test.
- `config/dwm/bin/dwm-display` — `--list` prints `label<TAB>command` without
  applying anything, which exists precisely so a test can read the menu.

## Notes
- **The shim lesson is the point of this task**, not an aside — see
  [[shims-must-match-real-output-format]]. Every fixture must be generated in
  the format the real tool emits: maim writes RGBA PNGs (`color_type 6`).
- **`xclip` must be shimmed or the test overwrites the user's real clipboard.**
  Same class as the `--automount` hazard: a test with a live side effect.
- ImageMagick asymmetry: `dwm-display`'s test needs only shims, so it runs
  everywhere. `dwm-colorpicker`'s needs REAL ImageMagick both to build fixtures
  and because the script calls it — shimming it would test nothing. When absent
  it must skip **loudly**; a silent skip in CI is the exact failure `--strict`
  was invented for (see the `lint.sh` note in CLAUDE.md).
- Local ImageMagick is 7.1.2 (`magick`); ubuntu-latest runners have historically
  shipped IM6 (`convert`). The script already probes both — the test should not
  assume either, and should report which it used.
- `dwm-display --list` is the seam to test against; do not drive the real dmenu.
  For selection dispatch, shim `dmenu` to echo one exact label back.
