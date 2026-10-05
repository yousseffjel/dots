# thunar-finalization

Date: 2026-08-07
Files: 12 | Lines: +676/-6 (source only; +847/-9 incl. task folder + state)

Epic sub-task 8 of `.claude/tasks/scope-b-app-roster-finalization.md`.

## What changed

- **Five new config files**, none of which existed before: `config/thunar/
  thunarrc` (preferences), `config/thunar/uca.xml` (custom actions),
  `config/xfce4/helpers.rc` (Xfce preferred applications),
  `config/mimeapps.list` (xdg mime defaults), and
  `config/applications/dots-nvim.desktop` (a terminal-editor entry).
- **`scripts/install-restore-apps.sh`** (new, 168 lines, sourced by
  `install-restore.sh`): copy-deploys those five with no-clobber semantics and
  APP manifest rows, refreshes the desktop database, then runs a guarded
  `xfconf-query` pass that is what actually applies Thunar's preferences.
- **`scripts/uninstall-apps.sh`** (new, 66 lines, sourced by `uninstall.sh`):
  the matching removal step, in its own file because `uninstall_steps.sh` is
  at 230 of the 250-line cap.
- **`packages/extra.lst`** gained `xfce4-settings` (plus a category comment on
  the pre-existing thunar block, which had none).
- **`docs/THUNAR.md`** (new) documents the two non-obvious mechanisms;
  `docs/UNINSTALL.md`'s category list gained the new **app configs** entry and
  the **theme files** entry it had been missing since the theming Epic.

## Why

The roster has shipped Thunar and its whole supporting cast — archive plugin,
volman, tumbler, file-roller, unar, catfish, gvfs — since sub-task 2, with no
configuration at all. This is that configuration, plus the two integration
points the scope file called for: alacritty named as the terminal, and xdg
mime defaults so firefox/feh/file-roller own their types.

Three findings changed the shape of the task away from what the scope file
assumed, each verified rather than inferred:

**`thunarrc` is a one-time migration file, not the live config.** Thunar 4.20
keeps preferences in the xfconf `thunar` channel. Upstream
`thunar_preferences_init()` reads `thunarrc` only when xfconf has no
`/last-view`, and even then skips any property xfconf already holds. This dev
host demonstrates it concretely: `thunar.xml` has `/last-view` and no
`thunarrc` exists at all, so a shipped file would have been inert here. Hence
the `xfconf-query` pass; `thunarrc` is kept only for a fresh install that has
never launched Thunar *and* could not reach a session D-Bus.

**`exo-open --launch TerminalEmulator` no longer works on its own.** Thunar
hardcodes that command for its built-in "Open Terminal Here", but exo 4.15.1
moved the helper framework out ("Removed binaries: exo-compose-mail,
exo-helper-2") into xfce4-settings, which now ships `xfce4-mime-helper` and
the `/usr/share/xfce4/helpers/*.desktop` definitions. Proved by intercepting
the call: a fake `xfce4-mime-helper` first on `PATH` received
`--launch TerminalEmulator echo hi`, and `libexo-2.so.0` contains only the
strings `xfce4-mime-helper`, `/xfce4/helpers.rc`, `[Default]` and a hardcoded
`xfce4-terminal.desktop` fallback. Fedora 43 ships exo 4.20.0 and
xfce4-settings 4.20.1, both past that split.

**GIO silently drops a desktop entry whose `Exec` binary is missing.** Found
while verifying `mimeapps.list` against real GIO — the archive entries
appeared broken until the stub's `Exec` pointed at a binary that exists. This
is why `dots-nvim.desktop` carries `TryExec=alacritty`.

## Assumptions

- **(Type A, re-asked) `xfce4-settings` is added to `extra.lst`.** The user's
  first answer was "helpers.rc only, no package", which rested on Fedora's exo
  still carrying the helper framework. Exploration disproved that, so the
  choice was surfaced with the evidence and re-asked rather than built as
  specified — the file would have been inert. The user then chose the full
  wiring. Nothing starts `xfsettingsd`; the package is there for one binary.
  Because `extra.lst` is best-effort, a failed install is contained: the
  right-click "Open Terminal Here" is a `uca.xml` action calling alacritty
  directly and keeps working; only Thunar's own File-menu entry goes quiet.
- **(Type B) Preferences deploy as xfconf pass + thunarrc fallback** (user
  choice of three). The pass **only sets a property with no value yet**, so an
  installer re-run never reverts a setting changed in Thunar's own dialog. The
  practical effect on an existing box is that `/last-view` — which Thunar
  writes itself to remember the view you left it in — is kept.
- **(Type B) `text/plain` gets its own `dots-nvim.desktop`** (user choice of
  three). The neovim package's `nvim.desktop` is `Terminal=true`, which hands
  terminal selection to GLib's compiled-in list; ours names alacritty outright
  so the behaviour does not shift with the GLib version.
- **(Type C) Everything here is COPIED, never symlinked.** Thunar rewrites
  `uca.xml`, xfce4-mime-settings rewrites `helpers.rc`, GIO rewrites
  `mimeapps.list`. Same rule that keeps `config/dunst` and `config/picom` out
  of `symlinks.sh`, which is why `symlinks.sh` was in the plan's Forbidden.
- **(Type C) `[Added Associations]` is populated alongside
  `[Default Applications]`** — a default only applies to a type the app is
  associated with, and neither feh nor file-roller declares every type listed.

## Trade-offs

**`docs/UNINSTALL.md` was already stale before this task** — its numbered
category list never documented the **theme files** step added by the theming
Epic. Fixed alongside the new entry rather than left, since the list is now
correct or it is not; renumbering it partially would be worse than either.

**Thunar's xfconf preferences are deliberately not reverted on uninstall.**
They sit in the user's own channel next to settings Thunar wrote itself,
nothing records their prior values, and resetting them is indistinguishable
from discarding choices made in the preferences dialog afterwards. Removing
files we created is reversible; guessing at prior state is not.

**The repo directory is `config/thunar/` but the target is
`~/.config/Thunar/`.** Lowercase matches every other `config/` entry; the
capital T is what Thunar actually reads. Called out in the script header, in
`docs/THUNAR.md`, and asserted in the harness.

## Test coverage

- `tests/lint.sh`, `tests/pkglist.sh`, `tests/build.sh` — all exit 0.
  `build.sh` is pure regression here (no C touched); run to confirm the slot
  is clean.
- **44 assertions across 9 scenarios** in a scratchpad harness with all four
  XDG vars redirected and `xfconf-query`/`update-desktop-database` faked on an
  isolated `PATH`. Covers: dry-run mutating nothing, first deploy, idempotent
  re-run, a user's own xfconf value surviving, a pre-existing config file left
  untouched *and* untracked, uninstall removing ours while keeping theirs, the
  headless no-D-Bus path, `xfconf-query` absent entirely, and an empty
  manifest.
- **Six mutants, all caught** (5/6/5/2/5/2 failing assertions): lowercase
  `thunar/` target, xfconf guard removed so it overwrites, pre-existing file
  wrongly given a manifest row, session-bus guard removed, uninstall ignoring
  the manifest, and single-click set to the wrong value.
- **Real-GIO check the fakes cannot make:** all 12 mime types resolved
  correctly through `gio mime` in a sandboxed XDG tree — including our
  `org.gnome.FileRoller.desktop` entry beating this host's system-wide
  `org.kde.ark.desktop` default. `desktop-file-validate` passes clean on
  `dots-nvim.desktop`; `uca.xml` parses as XML and its wallpaper command
  tokenises to the intended 5-element argv, verified to pass a filename
  containing a space through as one argument, on both the `XDG_CONFIG_HOME`
  and `$HOME` fallback branches.

**Not covered:** no `dnf`, no Fedora, and Thunar has never been launched
against these files. The xfconf property names and enum forms are confirmed
against upstream `thunar-preferences.c`/`thunar-enum-types.c` and a live
`thunar.xml`, but not by watching Thunar read them. The harness lives in the
scratchpad and is not part of `tests/`, so CI will never re-run it.

## Follow-ups

- **`install-restore-theme.sh` has the same SIGPIPE bug this task's audit
  fixed.** `theme_is_ours` and `theme_backed_up` both pipe into `grep -qxF`;
  grep's early exit can SIGPIPE `cut`, and under `set -o pipefail` the
  pipeline returns 141 even on a match — so a file we deployed is misreported
  as one to leave alone. Demonstrated 5/5 on a 200k-row manifest. Not fixed
  here: that file was not in this plan's Allowed list, and fixing it would be
  a silent scope expansion. Low urgency (the theme manifest is a handful of
  rows), but it is a real latent bug in shipped code.
- **`xfconf` and `desktop-file-utils` are undeclared in `packages/*.lst`.**
  Both are hard transitive deps of `thunar` and both call sites are
  `command -v` guarded, so nothing breaks — but this is the fifth sub-task to
  feed the queued core.lst/extra.lst promotion pass.
- **Per-task harnesses die with the session.** This one and sub-tasks 5-7's
  were all scratchpad-only. Worth deciding whether they belong in `tests/`,
  alongside the queued `tests/lint.sh` glob widening.
- **`CLAUDE.md`'s project map lists neither `config/thunar`, `config/xfce4`,
  `config/applications`, `config/mimeapps.list`, nor the two new scripts.**
  Sub-task 9 owns that reconciliation, as it does for sub-tasks 5-7.
- **Unverified on the target:** that `xfce4-settings` exists and carries
  `xfce4-mime-helper` on the actual Fedora box (confirmed via the Fedora
  package page and the Arch files DB, not a live `dnf`), and that Thunar's
  built-in "Open Terminal Here" then opens alacritty.
