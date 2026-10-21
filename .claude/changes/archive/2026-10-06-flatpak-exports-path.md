# flatpak-exports-path
Date: 2026-10-06
Files: 2 | Lines: +11/-0
Micro task, committed on main without a slot. `/explore` and `/plan` were
skipped as Micro: one config file plus its CHANGELOG line.

## What changed
- `config/zsh/.zshenv`: `"$XDG_DATA_HOME/flatpak/exports/bin"` and
  `/var/lib/flatpak/exports/bin` are appended LAST to zsh's `path` array, so
  app-ID launchers (`org.xfce.mousepad`) never shadow a native command.
  `typeset -U` already dedups.
- `CHANGELOG.md` (Added).

## Why
scope-e decision 10. On the VM, Flatpak apps could only be started with
`flatpak run`, and `dmenu_run` (Mod+p) did not list them.

## Assumptions
- Type B: the dwm session is started through the user's login zsh. That is
  the only way `.zshenv` reaches dwm and dmenu, and the repo's own comment in
  `install-session-template.sh` (dwm-lock) already calls it not guaranteed.
  The reviewer returned WARN because the first CHANGELOG wording promised
  dmenu unconditionally. It was reworded to state that condition, which is
  the same one `~/.config/dwm/bin` has always depended on.

## Test coverage
- Sandboxed `env -i` zsh run:
  - both dirs land last on `path`, with `$XDG_DATA_HOME` expanded from the
    default set earlier in the file;
  - sourcing twice leaves no duplicates (`typeset -U`);
  - `zsh -n` parses.
- `tests/run-tests.sh`: 40 OK, 0 FAIL. `tests/lint.sh` clean.
- Audit: Small tier, 0 issues. Reviewer: WARN (CHANGELOG wording), resolved.
- Not checked on the VM: Mod+p listing a Flatpak app.

## Follow-ups
- VM:
  - pull and log out/in;
  - check that Mod+p lists `org.xfce.mousepad`;
  - if not, `echo $PATH` from a terminal dwm spawned shows whether `.zshenv`
    reached the session at all. If it didn't, `~/.config/dwm/bin` is missing
    too, and the fix is in how ly starts the session.
- **The portal fix was never on the VM.** The VM's `git pull` said "Already
  up to date" because main (6 commits) had not been pushed, so
  `dots-session.target` was not deployed. The pasted `~/.xinitrc` block fell
  back to `exec dwm`, and Text Editor stayed light. That fallback working was
  itself the first real-session evidence that a missing unit cannot brick
  the login.
