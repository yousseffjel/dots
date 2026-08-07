# screenshot-maim-slop

Date: 2026-08-07
Files: 4 | Lines: +475/-18 (incl. task folder)

Epic sub-task 5 of `.claude/tasks/scope-b-app-roster-finalization.md`.

## What changed

- **`config/dwm/bin/dwm-screenshot` (new, 246 lines).** A dmenu-driven wrapper
  over maim + slop + xclip. Two prompts in sequence — mode
  (`full`/`window`/`region`), then destination
  (`clipboard`/`file`/`both`) — either of which is skipped when the matching
  flag is passed, so a keybind can jump straight to one combination. Escape at
  either prompt aborts silently. Files land in `~/Pictures/screenshots`,
  overridable with `DOTS_SCREENSHOT_DIR`, named
  `dots-screenshot-YYYYmmdd-HHMMSS.png`.
- **The slop selector is themed.** `dwm.selbordercolor` is read live from
  `xrdb -query` and converted to the float RGBA `slop --color` wants, so the
  selection rectangle matches the border dwm draws around the focused window
  and re-themes with the wallpaper for free. Unthemed, it falls back to slop's
  own grey rather than failing.
- **`config/sxhkd/sxhkdrc`.** `Print` and `shift + Print` uncommented and
  finalised. The header's ownership note was corrected: it claimed every
  binding here is an `XF86*` key or in the `Super` space, which `Print` makes
  false.
- **`packages/extra.lst`.** `xprop` added, with a comment recording why it and
  not `xdotool`.
- **`KEYBINDINGS.md`.** New Screenshot section under `## sxhkd`; the two rows
  removed from "Not yet bound", leaving only sub-task 6's lock binding.

## Why

Locked decision 2 chose maim + slop behind a dmenu menu, matching
`dwm-powermenu`; flameshot was rejected *because* it is Qt, and the desktop is
GTK-only (locked decision 3). Sub-task 4 built the sxhkd layer and reserved
`Print` for this, commented out. This fills it in.

`Print` is absent from dwm's `keys[]`, so sxhkd may grab it and
`config.def.h` is untouched — no rebuild, and none of the `rm -f config.h`
staleness handling sub-task 3 needed.

## Assumptions

- **(Type B) `xprop` over `xdotool` for the active-window id.** `xprop -root
  _NET_ACTIVE_WINDOW` plus one `awk` yields the `0x`-prefixed form, and maim
  parses it verbatim — confirmed by invocation, not assumed. `xdotool` would
  need no parsing but drags in libxdo for a single lookup. Both were offered
  to the user with the trade-off; they chose xprop. Verified present for
  Fedora 43/44/rawhide on packages.fedoraproject.org (no `dnf` on this Arch
  dev host, per CLAUDE.md rule 8).
- **(Type B) `shift + Print` goes to the clipboard only, not to disk.** Region
  grabs are overwhelmingly paste-once, and a keybind that quietly fills a
  directory is one you end up cleaning up after. The cost is a lost capture if
  the user forgets to paste; `Print` is the deliberate path when it should be
  kept.
- **(Type B) An empty result from slop is read as a cancel.** slop exits 1 with
  empty stdout for both Escape and a genuine failure and does not distinguish
  them. Its stderr is therefore *not* discarded, which is the only thing
  separating the two for the user.
- **(Type C) `~/Pictures/screenshots` + `DOTS_SCREENSHOT_DIR`**, mirroring
  `wallpaper.sh`'s `~/Pictures/wallpapers` + `DOTS_WALLPAPER_DIR`.

## Trade-offs

**`window` mode overlaps `region` mode more than the scope file implies.**
slop's default `--tolerance` of 2 means a plain click inside a region
selection already snaps to the window under the pointer. Window mode's only
real advantage is being mouse-free. Kept because the scope file specifies
three modes and a no-mouse path is worth a keystroke, but it is not an
independent capability and the docs say so.

**Screenshots are created 0600**, inherited from `mktemp` rather than chosen —
maim alone would write 0644 minus umask. Private-by-default is the better
posture for a screenshot, so this was left as-is rather than widened.

**Three defects were found by the audit loop, not by the plan.** All three
were live bugs in the first draft: `xclip` was required at startup though
`--file` never touches the clipboard; slop's stderr was discarded, making a
failed pointer grab both silent and indistinguishable from a cancel; and the
destination was validated only inside `deliver()`, i.e. after the capture had
run — in region mode, after a whole selection drag performed for nothing.
Adding the up-front validation then made the `*)` arms in `capture()` and
`deliver()` unreachable duplicates of the valid-value lists, and the file had
reached 249 of the 250-line cap; removing them fixed both at once (246 lines).

## Test coverage

- `tests/lint.sh`, `tests/pkglist.sh`, `tests/build.sh` — all pass. All five
  suckless programs build with no new warnings, confirming nothing here needs
  a rebuild.
- **70 assertions across 25 scenarios** in a scratchpad harness that fakes
  `maim`, `slop`, `xclip`, `xprop`, `xrdb`, `dmenu` and `notify-send` on an
  isolated `PATH`, so nothing captured the real screen or touched the real
  clipboard. Covered: every mode x destination pair; both prompts and Escape
  at each; `_NET_ACTIVE_WINDOW` returning `0x0`, `not found.` and a dead
  xprop; slop cancelled vs slop erroring; an unthemed xrdb; maim failing and
  maim producing an empty file; invalid values typed into dmenu; and each of
  maim/xclip/xprop being absent.
- Two **harness** bugs were caught and fixed mid-run, both of which had been
  producing false passes: `/usr/bin` was left on `PATH`, so the three
  "binary not installed" cases were silently exercising the real binaries;
  and the fake `dmenu` called `cat`, which the isolated `PATH` then lacked.
- `sxhkdrc` parse-tested with real `sxhkd` 0.6.3, clean — proven meaningful
  first by feeding it `Prnt` and confirming it reports `Unknown keysym name`.
- Real-binary checks that the fakes cannot make: `slop` and `maim` accept the
  exact flags passed, and `xrdb -query` against the live database returns
  `dwm.selbordercolor: #9A9AE6`, which the conversion turns into
  `0.604,0.604,0.902,1`.

**Not covered by CI:** `tests/lint.sh` globs `find . -maxdepth 2 -name '*.sh'`,
so `config/dwm/bin/dwm-screenshot` is outside it, as are the five other
`dwm-*` scripts. Shellchecked and `shfmt`'d by hand.

## Follow-ups

- **Widen `tests/lint.sh`'s glob to cover `config/dwm/bin/*`.** Carried from
  sub-task 4 and now more pressing: this is the second script there with real
  branching, and the largest at 246 lines.
- **`maim`, `slop` and `xprop` are all in `extra.lst`, which is best-effort.**
  A failed install leaves both keybinds dead. Same shape as the `sxhkd` and
  `alacritty` follow-ups; the case for promoting the roster's load-bearing
  packages to `core.lst` keeps growing.
- **`dwm-screenshot` is at 246 of 250 lines.** Sub-task 6 or 11 adding
  anything to it will cross the cap; the split seam would be the theming
  helpers (`hex2rgba` + `selector_color`), which sub-task 6 may want anyway.
- **`CLAUDE.md` and `ROADMAP.md` §3 still say no screenshot tool exists.**
  Left deliberately — sub-task 9's declared scope covers reconciling that
  list, and this is ordinary staleness rather than actively misleading advice.
- **Untested on real hardware:** no X11 dwm session here, so the `Print` grab,
  the themed selector's appearance and the active-window capture are all
  verified by construction and by fakes, not by use.
