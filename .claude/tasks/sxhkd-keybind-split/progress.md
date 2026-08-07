# Progress — sxhkd-keybind-split

## Status

`in-progress`

## Steps

- [x] 1. `config/sxhkd/sxhkdrc` — media/volume/mic (+ dwmblocks RTMIN+7/8), theming, firefox/thunar, reload; screenshot + lock blocks commented for sub-tasks 5/6.
- [x] 2. `config/dwm/bin/dwm-brightness` — xrandr gamma get/set with clamping, fires RTMIN+6.
- [x] 3. `scripts/symlinks.sh` — add `config/sxhkd` to `LINKS`.
- [x] 4. `scripts/install-suckless.sh` — launch sxhkd from the autostart template; yellow "add it yourself" branch when autostart.sh already exists.
- [x] 5. `packages/extra.lst` — drop `brightnessctl`, document it under NOT LISTED HERE.
- [x] 6. `suckless/dwm/config.def.h` — replace the commented theming keybind block with a pointer to sxhkdrc (comment-only, no active bind change).
- [x] 7. `KEYBINDINGS.md` — sxhkd section + who-owns-what note.

## Deviations

**Step 4 — `scripts/install-session.sh` extracted (new file, outside the
original `## Allowed`).** Adding the sxhkd autostart branch took
`install-suckless.sh` from ~240 to **253 lines**, over
`file-architecture.md`'s 250-line hard cap. There is no `exclude_line_cap`
carve-out in this repo, and `install-suckless.sh` was the only file over the
cap.

Escalated to the user rather than self-granting an exception (per the
`escalate-rule-conflicts-dont-self-except` memory — the same mistake was made
and caught by the reviewer during `packages-roster-fonts`). Three options were
offered: split, trim the new comments to fit, or accept the overage. The user
chose the split.

Lines 158–245 (autostart hook + `.xinitrc`) moved to
`scripts/install-session.sh`, sourced by `install-suckless.sh` — the same
arrangement `install-restore.sh` already has with `install-restore-theme.sh`.
The seam is clean: the moved code depends only on `DRY_RUN`, `HOME`,
`XDG_DATA_HOME` and the caller's colour helpers. Result: 172 + 120 lines, both
well under the cap.

Verified behaviour-preserving: the written `autostart.sh` was diffed against
the one HEAD's version produces, and the **only** difference is the intended
sxhkd block. All four branches (dry-run / fresh write / idempotent re-run /
pre-existing user file) re-tested after the move.

## Extra work not in the plan

- `config/dwm/bin/dwm-wallpaper` cited `20-path.zsh`, deleted in sub-task 1.
  Comment-only fix, in-scope (`config/dwm/bin/*` is in `## Allowed`). The same
  stale reference in `suckless/dwm/config.def.h` was removed with the block
  step 6 replaced. `CLAUDE.md:35` still carries it — sub-task 9's.
- `KEYBINDINGS.md` restructured to a single H1 with `## dwm` / `## sxhkd`
  owner sections and H3 subsections. Required: a second `# sxhkd` H1 trips
  markdownlint MD025, which `.markdownlint.yaml` leaves enabled.

## Blockers

_(none)_

## Step 8 (added mid-task, user-approved)

- [x] 8. Correct `docs/THEMING.md` and `CLAUDE.md`.

`## Allowed` was extended to cover both files first — this was open follow-up
#2 from the `/code` and `/test` summaries, and the user chose to fix it in this
slot rather than defer to sub-task 9.

Not merely stale: both told the reader to uncomment the theming binds in
`config.def.h`, which now collide with sxhkd's `Super+w`. The `XGrabKey` loser
fails silently, so following the docs would have produced a bug with no error
to trace. Both now carry a "do not re-add them there" warning naming the cause.

Two findings on the first draft of this step, caught by the incremental audit:
duplicating the keybind table into `THEMING.md` where a cross-reference already
existed (drift risk — reverted to a pointer), and claiming the binds are
"active on install" when `sxhkd` sits in best-effort `extra.lst` (the same
class of overclaim the reviewer caught in sub-task 3).

Deliberately **not** touched, both still sub-task 9's by its declared scope
("`CLAUDE.md` (roster + project map)"): `CLAUDE.md:35`'s stale
`20-path.zsh` reference, and the project map, which does not yet list
`config/sxhkd/` or `scripts/install-session.sh`.
