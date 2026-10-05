# clipmenu-copr-swap-fedora

## Session Date
2026-08-05

## Context
Same-day follow-up to `.claude/changes/2026-08-05-dmenu-only-drop-rofi.md`,
which had wired `dwm-clipmenu` (Super+Shift+c) to CopyQ because it was
already an installed package. The user asked for the keybind to change to
`Super+v`, and separately asked whether CopyQ was actually the best option
for this or whether something else fit better. After being told the
suckless-idiomatic alternative was `clipmenu`/`clipnotify` (a closer
philosophical match to dmenu, but AUR-only on Arch / COPR-only on Fedora —
not previously wired because it would've meant a new, unapproved
dependency), the user chose to switch to clipmenu, explicitly scoped this
to Fedora only ("forget arch" for now), and explicitly authorized enabling
the third-party COPR repo needed for it.

## What Was Requested
1. Change `dwm-clipmenu`'s keybind from `Super+Shift+c` to `Super+v`.
2. Assess whether CopyQ was the best clipboard-manager choice or whether an
   alternative fit better.
3. Following that assessment: switch to `clipmenu`/`clipnotify`, Fedora
   only (not Arch), with explicit authorization to auto-enable the COPR
   repo that provides them.

## What Was Implemented or Decided
- `suckless/dwm/config.def.h` (+ the local, gitignored `config.h` build
  artifact, kept in sync as before): changed the clipmenu keybind from
  `Mod4Mask|ShiftMask, XK_c` to `Mod4Mask, XK_v`. Verified no collision
  against the full `keys[]` array — `Mod4Mask` alone was entirely unused
  before this. Rebuilt (`make -C suckless/dwm`) to confirm it still
  compiles clean.
- `config/dwm/bin/dwm-clipmenu`: rewritten from a CopyQ-based script
  (manual `copyq eval`/`read`/`select` calls, ~30 lines) to a thin wrapper
  (~11 lines) that just `exec`s `clipmenu` with dwm's theme flags —
  `clipmenu` (cdown/clipmenu) already handles listing history through
  dmenu and copying the selection back internally, so no manual
  list-building/index-matching logic is needed anymore. Simpler and less
  code than the CopyQ version it replaces.
- `scripts/install-fedora.sh`:
  - Removed `copyq` from the desktop-utilities package list — nothing in
    the repo uses it anymore.
  - Added `dnf-plugins-core` to the core-packages list so the `dnf copr`
    subcommand is guaranteed to exist before the COPR-enable step runs
    (relevant on dnf4-based Fedora; could not be live-verified against an
    actual Fedora machine in this environment — see Open Questions).
  - Added a new best-effort step: `dnf copr enable -y skidnik/clipmenu`,
    then installs `clipmenu` and `clipnotify` from it. Wrapped in
    if/else so a failed COPR enable degrades to a yellow warning rather
    than aborting the script (`set -euo pipefail` compatible).
  - Updated the header comment to document this as a deliberate exception
    to the script's normal COPR-is-manual-only convention (contrast with
    the still-manual `lazygit`/`bibata-cursor-themes` COPR notes directly
    above it).
- `scripts/install-suckless.sh`: extended the generated `autostart.sh`
  template to also start `clipmenud` in the background
  (`command -v clipmenud >/dev/null 2>&1 && ! pgrep -x clipmenud ... && clipmenud &`),
  mirroring the existing `dwmblocks` launch guard exactly. Added a
  parallel yellow-reminder branch for the case where `autostart.sh`
  already exists but doesn't mention `clipmenud` (matching the existing
  dwmblocks reminder), respecting the "never overwrite user
  customizations" rule for pre-existing autostart.sh files.
- `ROADMAP.md` / `CLAUDE.md`: updated every CopyQ reference to describe
  clipmenu/clipnotify instead, noted the keybind is now `Super+v`, flagged
  this as Fedora-only (Arch's `install-arch.sh` still installs `copyq`,
  now dead weight there, and hasn't been wired for clipmenu — deliberately
  left untouched per instruction), and documented the COPR auto-enable as
  an explicit, user-approved exception inline in both files' relevant
  rule/rows (CLAUDE.md rule 4, ROADMAP.md §4.3).
- Ran the (React-Native-flavored, substituted with shell/C-appropriate
  checks as in the prior log) `audit-loop` self-audit: found and fixed one
  real issue — `dnf copr enable` could fail on dnf4 Fedora if the `copr`
  plugin isn't already present; fixed by adding `dnf-plugins-core` to the
  install list ahead of the COPR-enable step.
- Spawned the `reviewer` subagent gate: `READY` — verified the keybind
  collision-check, confirmed the `dnf-plugins-core` ordering fix, confirmed
  the autostart pattern mirrors the existing dwmblocks guard, and confirmed
  `install-arch.sh` was correctly left untouched.

## Files Modified
- `config/dwm/bin/dwm-clipmenu` (rewritten)
- `suckless/dwm/config.def.h` (modified — keybind change)
- `suckless/dwm/config.h` (local build artifact, gitignored — kept in sync)
- `scripts/install-fedora.sh` (modified)
- `scripts/install-suckless.sh` (modified)
- `ROADMAP.md` (modified — untracked file, pre-existing content)
- `CLAUDE.md` (modified — untracked file, pre-existing content)

## Key Technical Decisions
1. **clipmenu over CopyQ**, reversing the prior session's decision. CopyQ
   was chosen then because it needed zero new dependencies; clipmenu is
   philosophically closer to dmenu/suckless (single-purpose, no Qt/tray),
   and the user explicitly weighed that trade-off and chose clipmenu once
   told it would require a COPR-only dependency. If wrong: the CopyQ
   version is preserved in this same day's earlier change-log entry and
   git history for `config/dwm/bin/dwm-clipmenu`.
2. **`skidnik/clipmenu` COPR auto-enabled, not just documented.** This
   repo's rule 4 default is to leave third-party repo enablement to the
   user via a comment + manual command. The user explicitly authorized
   auto-enabling this one in-session ("you can enable the third-party"),
   which is exactly the trust decision rule 4 says must come from the
   user — so auto-enabling here doesn't violate the rule's intent, and is
   flagged inline in both `install-fedora.sh` and `CLAUDE.md` as a
   one-off exception, not a new default.
3. **Fedora-only.** User explicitly said "forget arch" for this task.
   `install-arch.sh` was left completely untouched — it still lists
   `copyq` (now unused anywhere) and has no clipmenu/clipnotify wiring.
   `config/dwm/bin/dwm-clipmenu` itself is a single shared script, so it
   would still try to run `clipmenu` on Arch — it just won't be installed
   there yet. This is a known, documented gap, not a silent one.
4. **`dnf-plugins-core` added ahead of the COPR-enable step.** Caught
   during self-audit — without it, `dnf copr` may not exist as a
   subcommand on some Fedora configurations, and the enable step would
   silently degrade to its yellow-warning branch instead of actually
   working. Could not be verified live against a real Fedora install in
   this environment (see Open Questions).

## Assumptions Made
- **Type C** — used web search (context7 had no `clipmenu` library entry)
  to confirm `skidnik/clipmenu` is an actively-monitored Fedora COPR
  providing both `clipmenu` and `clipnotify` packages, and fetched
  cdown/clipmenu's README for exact CLI/env-var behavior (`clipmenud`
  daemon, `clipmenu` picker forwards all args straight to dmenu,
  `clipnotify` is a hard runtime dependency of `clipmenud`) before writing
  the new `dwm-clipmenu` wrapper and the installer wiring.
- **Type B** — assumed the COPR-provided RPM package names are literally
  `clipmenu` and `clipnotify` (matching upstream project names, the
  standard COPR convention), since the COPR project page itself was
  blocked by an anti-bot wall (Anubis) and only search-result snippets
  were available to confirm this. If wrong: `dnf search clipmenu` /
  `dnf search clipnotify` on the target machine will show the actual
  names, and `scripts/install-fedora.sh`'s package list is a one-line fix.

## Trade-offs
- Chose plain background-process autostart (`clipmenud &` in
  `autostart.sh`, matching the existing dwmblocks pattern) over a
  systemd `--user` unit, even though upstream clipmenu ships one. This
  repo's whole session-autostart model is `.xinitrc` + `autostart.sh`
  (ROADMAP.md's own "Session autostart" row), not systemd `--user` X
  session management — using the systemd unit would have required
  `systemctl --user import-environment DISPLAY` wiring that doesn't fit
  anywhere else in this repo's startx-based flow. The plain-background
  approach is simpler and consistent with how dwmblocks is already
  started.

## Open Questions / Blockers
- **Could not live-verify Fedora package/plugin names.** No live Fedora
  machine is available in this environment (same limitation noted in
  `.claude/changes/2026-08-04-fedora-arch-install-scripts-verify-fix.md`).
  Specifically unverified: (1) whether `dnf-plugins-core` is still the
  correct package for the `dnf copr` subcommand on current dnf5-based
  Fedora (41+), or whether it's been superseded by `dnf5-plugins` /
  built into dnf5 by default; (2) whether `skidnik/clipmenu`'s COPR
  package names are exactly `clipmenu` and `clipnotify`. Both failure
  modes degrade gracefully (best-effort install loop, yellow warning,
  script continues) rather than aborting, but the feature itself
  (`Super+v`) would silently not work until corrected.

## Next Steps
- Smoke-test on real Fedora hardware: run `install-fedora.sh`, confirm
  `dnf copr enable -y skidnik/clipmenu` actually succeeds, confirm
  `clipmenu`/`clipnotify` install, confirm `clipmenud` shows up running
  after a fresh X session start, and confirm `Super+v` pops the themed
  dmenu clipboard list and pastes the selection back correctly.
- If/when Arch support for this feature is wanted: `install-arch.sh`
  needs (a) `copyq` removed from its package list (dead weight now), and
  (b) clipmenu/clipnotify wired in — clipmenu is AUR-only on Arch, so per
  rule 4 that means a header-comment note + manual `yay -S clipmenu
  clipnotify` instruction, not an auto-install, unless the user gives the
  same explicit auto-enable authorization they gave for the Fedora COPR
  here.
- `KEYBINDINGS.md` still doesn't exist (pre-existing gap) — once it does,
  record `Super+v` (not the earlier `Super+Shift+c`) for the clipboard
  menu.
