# Context — packages-roster-fonts

## Background
Sub-task 2 of the Epic "app / tool / package roster finalization"
(`.claude/tasks/scope-b-app-roster-finalization.md`, main-side — read its
14 locked decisions first). This is the second of ten and, with sub-task 1,
one of the two that unblock everything downstream.

It grew a second half after sub-task 1 merged. Deploying `symlinks.sh` would
have displaced a 405-line hand-tuned `~/.config/starship/starship.toml` the
user already had, replacing it with the 103-line ASCII placeholder shipped in
sub-task 1. `fc-list` then showed 135 Nerd Font matches installed, which
settled a question that had been open since the roster survey.

## Prior Decisions
- **Locked decision 13** — adopt the user's `starship.toml` into the repo.
- **Locked decision 14** — package *both* `CaskaydiaCove` (prompt/terminal,
  what the user actually runs) and `JetBrainsMono` (UI surfaces) Nerd Fonts.
- **Locked decision 8** — RAR via `unar` (Fedora official), never `unrar`
  (RPM Fusion nonfree). Enabling a nonfree third-party repo is the user's
  trust decision, not the installer's (CLAUDE.md rule 4).
- **Locked decisions 9 and 10** — desktop target, so no
  `power-profiles-daemon`; brightness is xrandr gamma, so no `ddcutil` and no
  `i2c-dev`.
- **Locked decision 6** — `kitty` is dropped, superseded by alacritty.
- `2026-08-05-clipmenu-copr-swap-fedora` established the one standing COPR
  exception (`skidnik/clipmenu`). Any further auto-enable needs an explicit
  ask — do not add a second one to make a package resolve.

## References
- Epic scope + all 14 locked decisions:
  `.claude/tasks/scope-b-app-roster-finalization.md` (main worktree only)
- `packages/core.lst` header — documents exactly what earns a slot in the
  hard-fail list; nothing here belongs there unless a later installer step
  unconditionally depends on it.
- `packages/extra.lst` — category comments (`# core system & display server`,
  `# fonts & theming`, …) are section dividers to keep, per rule 10.
- `tests/pkglist.sh` — offline syntax/duplicate/overlap check. The CI
  `install-dry-run` job is what validates names against live repos.
- `.claude/changes/2026-08-06-zsh-dehyde-x11.md` — sub-task 1's log, which
  records the Nerd Font gap as a follow-up landing here.

## Notes
**Verification constraint.** No `dnf` on this host (Arch), so rule 8's "check
against packages.fedoraproject.org" means real lookups over the network, not
inference from Arch package names. Fedora and Arch disagree often enough that
translation is unsafe — Arch's `ttf-cascadia-code-nerd` has no relation to
Fedora's naming, and Fedora splits Nerd Fonts per family.

**Names most likely to be wrong**, worth checking first: the two Nerd Fonts,
`xss-lock` (may be `xss-lock` or absent), `unar`, `catfish`,
`ffmpegthumbnailer`, `thunar-volman`. `firefox`, `bluez`, `blueman`, `maim`,
`slop` are near-certain but still get checked.

**core.lst stays untouched** unless something here is a hard dependency of a
later installer step, which none of these are — they are all best-effort.

**Starship adoption caveats** (from the scope file): the `󰣇` Arch logo is
wrong for Fedora, and `right_format` lists ~60 language modules whose
detection runs on every prompt — the one part in tension with the user's
"max performance" constraint. Measure before proposing a trim; the user
decides how far to cut. The config also hardcodes hex colours in ~10 places
(`#8be9fd`, `#769ff0`, `#394260`, `#a0a9cb`, `#9198a1`), which sub-task 9's
theming template will have to rewrite as literals — there is no `[palettes]`
table to swap, unlike the placeholder being replaced.
