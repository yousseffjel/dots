# sxhkd-keybind-split

Date: 2026-08-07
Files: 11 | Lines: +560/-125

Epic sub-task 4 of `.claude/tasks/scope-b-app-roster-finalization.md`.

## What changed

- **`config/sxhkd/sxhkdrc` (new, 128 lines).** The hotkey layer dwm does not
  own: media (`playerctl` over MPRIS), volume and mic (`pamixer`), brightness,
  the theming engine, and two app launchers. Screenshot and lock ship
  commented out, each annotated with the sub-task that activates it.
- **`config/dwm/bin/dwm-brightness` (new, 117 lines).** `xrandr --brightness`
  gamma control with `get|up|down|set`, clamped to 10–100%, applied to every
  connected output so displays that have drifted apart converge. `get` is the
  read side for sub-task 7's status block.
- **`scripts/install-session.sh` (new, 134 lines).** The `autostart.sh` hook
  and `~/.xinitrc`, split out of `install-suckless.sh` — see Trade-offs.
- **`scripts/install-suckless.sh`.** Now starts sxhkd from the autostart
  template, warns when a pre-existing `autostart.sh` lacks it, and sources
  `install-session.sh` for the session wiring. 253 → 172 lines.
- **`scripts/symlinks.sh`.** `config/sxhkd` added to `LINKS`.
- **`packages/extra.lst`.** `brightnessctl` dropped and documented under
  NOT LISTED HERE; a note added explaining what `playerctl` and `pamixer` back.
- **`suckless/dwm/config.def.h`.** Comment-only. The commented-out theming
  keybind block is replaced by a "these are NOT here, and here is why you must
  not re-add them" note.
- **`KEYBINDINGS.md`.** Restructured into `## dwm` and `## sxhkd` owner
  sections under one H1, with the disjoint-grab rule stated up front.
- **`docs/THEMING.md`, `CLAUDE.md`.** Both told the reader to uncomment the
  theming binds in `config.def.h`. Corrected — see Follow-ups for what was
  deliberately left.
- **`config/dwm/bin/dwm-wallpaper`.** Comment-only: cited `20-path.zsh`,
  deleted in sub-task 1.

## Why

Locked decision 7 keeps sxhkd in the roster. It had been packaged since
sub-task 2 but the repo shipped no `config/sxhkd/`, so the installer pulled in
a daemon that never started and read a config that did not exist. This closes
that gap and unblocks sub-tasks 5, 6 and 11, all of which add bindings.

The user chose the most conservative of the three splits offered: **dwm keeps
every binding it already has**, and sxhkd takes only what does not exist yet.
That turned out to be the strongest option for a reason worth recording —
`config.def.h`'s diff is comment-only, verified mechanically, so existing
installs get the entire sxhkd layer with no rebuild and none of the
`rm -f config.h` staleness dance that sub-task 3 had to document.

The theming keybinds are the one thing that did move. They were shipped
commented out precisely because enabling them cost a recompile; as sxhkd
bindings that objection disappears, so they are live on install (`Mod+w` →
`Super+w`).

## Assumptions

- **(Type B) sxhkd's grabs and dwm's do not overlap, verified by reading both
  key sets rather than by testing on a live session.** dwm owns `Mod` plus
  `Super+Shift+x` and `Super+v`; sxhkd owns the `XF86*` keys and
  `Super`+{w, Shift+w, Ctrl+w, b, e, Ctrl+r}. Disjoint. Not exercised against
  a running dwm — this host runs Wayland. If wrong, the symptom is a key that
  does nothing at all, with no error anywhere; `xev` identifies the winner.
- **(Type B) Raising the volume unmutes; lowering does not.** Matches what a
  hardware volume key does on other desktops. Turning a muted system down
  should not make it audible.
- **(Type C) `procps-ng` is not declared** for `pkill`/`pgrep`. It is a Fedora
  `@core` package and the repo already depended on it (`reload.sh`,
  `dwm-powermenu`, three `.dcol` templates) before this task.

## Trade-offs

**RECLASSIFICATION — Medium → Large,** surfaced at plan time. The scope file
estimated `sxhkdrc` + `config.def.h` + autostart + docs + `symlinks.sh`.
Exploration added `config/dwm/bin/dwm-brightness` (xrandr gamma needs output
enumeration and clamping, not a one-liner) and `packages/extra.lst`, taking it
to 7 files across 4 layers. Confirmed with the user before coding.

**DEVIATION — `scripts/install-session.sh` extracted.** Adding the sxhkd
autostart branch took `install-suckless.sh` from ~240 to **253 lines**, past
`file-architecture.md`'s 250-line hard stop, with no `exclude_line_cap`
carve-out in this repo. Escalated to the user rather than self-granted as an
exception — three options were offered (split / trim the new comments / accept
the overage) and the split was chosen. Lines 158–245 moved out, the same
arrangement `install-restore.sh` already has with `install-restore-theme.sh`,
whose header records it as having been created for exactly this reason.
Proven behaviour-preserving by diffing the generated `autostart.sh` against the
one HEAD produces: the only difference is the intended sxhkd block.

**Scope extended mid-task, with approval,** to `docs/THEMING.md` and
`CLAUDE.md` after `/test`. Both were not merely stale but actively harmful:
following them meant uncommenting a block that now collides with `Super+w`,
and the `XGrabKey` loser fails silently.

## Test coverage

All three CI-mirroring suites, run in the slot worktree with the branch
confirmed first:

- `tests/lint.sh` — shellcheck, `shfmt -i 4 -ci -bn -d`, markdownlint: **pass**.
- `tests/pkglist.sh` — format, duplicates, core/extra overlap: **pass**.
- `tests/build.sh` — all five suckless programs built, dwm with no new
  compiler warnings from the comment change: **pass**.

Beyond the suites:

- **`sxhkdrc` parse-tested with the real `sxhkd` 0.6.3.** Clean. The test was
  first proven meaningful by feeding it a bad keysym and confirming it reports
  `Unknown keysym name` — so "no output" genuinely means every `XF86*` name
  resolves.
- **`dwm-brightness` exercised against a fake `xrandr` on `PATH`**, not the
  live display, which this change would otherwise have dimmed. Covered: the
  disconnected-output trap (a `DP-3 disconnected` entry carrying its own
  `Brightness: 0.99` must not be read or written), both clamps, multi-output
  convergence, non-numeric input, headless, and a failing xrandr.
- **All four `autostart.sh` branches** re-tested after the refactor in a
  sandbox overriding all four XDG variables: dry-run, fresh write, idempotent
  re-run, and a pre-existing user file — which was confirmed byte-unchanged
  (CLAUDE.md rule 6). No rows leaked into the real manifest.
- `symlinks.sh --list-links` reports the sxhkd pair, so `install-restore.sh`'s
  manifest writer registers it and `uninstall.sh` covers it with no new code.

**Not covered by CI:** `tests/lint.sh` globs `find . -maxdepth 2 -name '*.sh'`,
so `config/dwm/bin/dwm-brightness` (depth 3, no `.sh` suffix) is outside it, as
are the four pre-existing `dwm-*` scripts. It was shellchecked and `shfmt`'d by
hand instead.

## Follow-ups

- **Widen `tests/lint.sh`'s glob to cover `config/dwm/bin/*`.** Five scripts
  currently sit outside CI. This task's is the first with real branching logic
  in it.
- **`sxhkd` is in `packages/extra.lst`, which is best-effort.** A failed
  install leaves *every* binding in this task dead. Same shape as the
  `alacritty` follow-up from sub-task 3; consider promoting both to
  `core.lst`.
- **The live grab-disjointness is unverified on real hardware** — no X11
  session here. Worth one `xev` check on first boot.
- **`CLAUDE.md:35` still cites the deleted `conf.d/20-path.zsh`, and the
  project map lists neither `config/sxhkd/` nor `scripts/install-session.sh`.**
  Left deliberately: sub-task 9's declared scope is "`CLAUDE.md` (roster +
  project map)". The theming-keybind line was fixed here because it was
  actively misleading; these two are ordinary staleness.
- **Brightness is gamma, not backlight.** Documented in three places, but the
  first person to press the key on a bright monitor may still be surprised
  that the panel does not actually dim.
- **`KEYBINDINGS.md` Scratchpads section still lists `st -n spterm` / ranger /
  keepassxc.** Accurate today; sub-task 11 replaces all three.
