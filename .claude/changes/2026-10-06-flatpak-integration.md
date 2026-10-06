# flatpak-integration
Date: 2026-10-06
Files: 21 code/docs (5 new) | Lines: +237/-12 tracked, +597 in the new code files

## What changed
- `packages/extra.lst`: `flatpak`, after the portal block. Verified on mdapi:
  f43 1.16.6, f44 1.18.4 (both `updates`).
- `scripts/install-restore-flatpak.sh` (new), sourced and called by
  `install-restore.sh` after `restore_apps`. `restore_flatpak`:
  - adds the Flathub remote with `remote-add --user --if-not-exists`. It
    writes a `FLATPAK remote flathub <url>` row only when no user remote
    called flathub existed before;
  - adds three `flatpak override --user --filesystem` grants
    (`~/.local/share/icons:ro`, `xdg-config/gtk-3.0:ro`,
    `xdg-config/fontconfig:ro`). Each is skipped when its path is already
    in the global override, in any mode or negated with `!`. A row
    `FLATPAK override <entry>` records the entry as flatpak wrote it, read
    back from the file.
  - It handles `--dry-run`, a missing `flatpak`, and being offline (yellow
    re-run hint).
- `scripts/global_fn.sh`: `flatpak_override_file`, `flatpak_grants`,
  `flatpak_grant_for` and `flatpak_grant_path` read
  `${FLATPAK_USER_DIR:-$XDG_DATA_HOME/flatpak}/overrides/global`. Both sides
  use them. The stale row-type list in the header was replaced with a
  pointer to `grep manifest_append_row` (it had already lacked DCONF).
- `scripts/uninstall-flatpak.sh` (new), called by `uninstall.sh` after
  `uninstall_dconf` and before `uninstall_packages`:
  - drops an entry only while it is still exactly as written;
  - drops a `[Context]` group left with no keys, and deletes a file left
    with no keys at all;
  - removes the remote only while `flatpak list --user --columns=origin`
    lists nothing from it;
  - reports a failed edit and carries on.
- `scripts/doctor-session.sh` + `doctor.sh`: `check_flatpak`, under the
  theme section. It warns on a missing grant or no Flathub remote (system
  or user), treats a grant set the user's own way as ok, and skips when
  there is no flatpak. The grant list is the installer's own
  `FLATPAK_GRANTS`, sourced.
- Tests:
  - `tests/flatpak-integration.sh` (new, 18 checks), with
    `tests/lib/fake-flatpak.sh` (shared fake) and `tests/lib/flatpak-real.sh`
    (the same round trip against a real flatpak when one is installed).
  - The symmetry sandbox gets the fake. FLATPAK joins its per-category
    loop, the lived-in HOME seeds its own override file, and the remote
    must be gone afterwards.
  - The doctor sandbox's grants are written by `restore_flatpak` itself,
    with 5 new checks.
- Docs: `CLAUDE.md` (rule 4 second exception, map rows, a "do not add
  GTK_THEME" note), `docs/UNINSTALL.md` (step 5b and two "kept" bullets),
  `CHANGELOG.md`, `ROADMAP.md` (§3 row and the package block), `TESTING.md`
  (entries for this test and the missing `color-scheme.sh` one, plus the
  symmetry fakes list, which also lacked dconf).
- `.claude/tasks/scope-e-flatpak-integration.md` (scope file with the
  locked decisions), moved here from main untracked.

## Why
The user asked to "focus on flatpaks and integration" and pasted a
GNOME/Flatseal guide. Two decision rounds are recorded in the scope file.
The guide's GUI steps are scripted here, under the same contract as the
portal's DCONF row: write only when absent, revert only when unchanged.

## Key Technical Decisions
- **DECISION REVERSAL — scope-e decision 3's `GTK_THEME`** (the user's
  first-round choice), dropped in the second round. GTK calls it a debugging
  variable, and set globally it breaks GTK4/libadwaita Flatpak layouts
  (gitlab.gnome.org/GNOME/gtk/-/issues/5661). It is also redundant here:
  - GTK3 gets the theme name from xsettingsd over the shared X socket, plus
    the `gtk-3.0:ro` grant;
  - GTK4 gets dark mode from the portal's colour scheme (f831138).
- **Rule 4 exception #2: Flathub auto-added**, explicitly authorised. Unlike
  the clipmenu COPR, it is reverted by uninstall.
- **The icons grant is not redundant.** flatpak-run.c binds the user icon
  dir at `/run/host/user-share/icons`, but only newer runtimes put that on
  the cursor search path (freedesktop-sdk MR 6777, merge status
  unconfirmed). At its real path the directory is on libXcursor's default
  search path on any runtime.
- **The keyfile is edited directly**: flatpak has no way to unset a single
  global grant (`--nofilesystem` adds a negation, `--reset` wipes
  everything). The format was taken from the real flatpak 1.18.4 in a
  sandboxed HOME, not written from memory:
  - entries are reordered on every write and `;`-terminated;
  - `[Context]` comes first, with a blank line before other groups;
  - `remotes` prints a lone newline when empty, and `list` prints nothing.
- **Plan deviation:** sourced from `install-restore.sh` (149 lines), not
  `install-restore-apps.sh` (220/250).

## Assumptions
- Type B: a user `flathub` remote alongside a Fedora Workstation system
  `flathub` is harmless. The check looks at the user installation only, so
  `flatpak install` may ask which installation to use.
- Type B: the fontconfig grant is a no-op today (dots ships no fontconfig),
  kept at the user's request.
- Type C: `~/.local/share/flatpak/` itself (repo/, summary cache) is
  flatpak's and is left on uninstall. Documented in UNINSTALL.md.

## Test coverage
- `tests/run-tests.sh`: 39 OK, 0 FAIL. `tests/lint.sh` clean (shellcheck,
  shfmt, markdownlint).
- Real flatpak 1.18.4 round trips, each in a fresh `mktemp` HOME with all
  XDG vars sandboxed:
  - fresh HOME, re-run, a lived-in HOME (`icons` rw + `!home`), and a grant
    changed after install;
  - seeded `[Environment]`, `!home` and `[Session Bus Policy]` files, each
    back byte for byte.
- Mutation testing on copies, never the worktree: 16/16 caught, each by its
  own assertion. A true unguarded-edit mutant was also caught, by the
  unwritable case alone. The first attempt at that mutant was caught for
  the wrong reason and was redone.
- Bugs the process found:
  - round-trip checks passing vacuously while the fake's shebang was broken
    (now guarded by a WROTE marker);
  - a missed look-alike-key mutant (new case);
  - an empty `[Context]` header left behind (now dropped);
  - a silent `set -e` abort on a failed edit (now guarded).
- The real `~/.local/share/flatpak/overrides/global` on the dev host stayed
  untouched (mtime 2026-10-02).
- **Not run on Fedora or the VM.** The cursor inside a real Flatpak app has
  not been seen.

## Follow-ups
- On the VM (`ysf@192.168.122.2`) after merge: `--only-restore`, install a
  Flathub GTK3 app, and check the Bibata cursor and wallpaper accents.
  `dots doctor` should show both flatpak rows ok.
- TESTING.md has no entry for `tests/doctor.sh` (pre-existing gap).
- The clipmenu COPR is still never reverted by uninstall (out of scope here).
- Post-merge on main: fold this log into CURRENT_AUDIT.md, and record scope
  E as closed in MASTER_PLAN.md.
