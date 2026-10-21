# theme-lock-scope
Date: 2026-10-21
Files: 8 (+ task folder) | Lines: +206/-41 (incl. task folder)

## What changed
- `scripts/theme/theme-lock.sh`: takes no lock when the first argument is `-h`, `--help`, `--list`, `--login-random` or `--select`.
- `scripts/theme/wallpaper.sh`: after the `--select` pick, `exec "$BASH" "${BASH_SOURCE[0]}" "$TARGET"`. The apply runs as a fresh path-mode run, which takes the lock. login_random and login_random_hint moved verbatim to the new `scripts/theme/wallpaper-login-random.sh` (sourced): wallpaper.sh was exactly at the 250-line cap and is now 220.
- `tests/theme-lock.sh`:
  - with the lock held, each read-only argument runs at once;
  - the real wallpaper.sh `--select` runs with a fake dmenu, which must find the lock free, and a stub colorgen, which must find it held, and must record the pick in wall.set.
- `tests/wallpaper-collection.sh`: reads the hint lines from the new file.
- CHANGELOG `[Unreleased]` line; CLAUDE.md project map.

## Why
Host edge-case pass: with the lock held, `dots theme --list` waited out DOTS_THEME_LOCK_WAIT and exited 75. `config/dwm/bin/dwm-theme` (Super+Shift+t) builds its dmenu from `theme-apply.sh --list`, so the theme menu stalled behind any wallpaper change, or failed after 60 s.
theme-lock.sh is sourced before argument parsing, so `wallpaper.sh --select` held the lock for as long as its picker stayed open. In that time Super+w and the theme menu failed, and from sxhkd the red message goes nowhere.
The lock exists to serialise changes (theme-change-lock, 2026-10-20). Reading a list, printing help or toggling the login flag changes nothing.

## Assumptions
- Type B: re-exec rather than locking in the middle of the script. It reuses the one locking mechanism unchanged.
- Type C: `--login-random` writes only its own flag file, so it is not a theme change.

## Test coverage
- New checks: 6 failures before the fix. They pass after.
- Two harness bugs were fixed along the way:
  - a 3-second lock holder expired mid-loop and masked 4 of the failures;
  - the fake read a missing lock directory as "held".
- Mutants on a scratch copy, 4/4 caught:
  - `--select` removed from the skip list;
  - the exec re-run removed;
  - `--list` removed from the skip list;
  - no skip at all.
- Full suite rc=0 (99 OK); lint passed; reviewer READY.
- Not VM-run: the ssh agent socket is gone (the key needs the user's passphrase).

## Follow-ups
- Same pass, minor, not fixed: on a never-installed HOME, `dots doctor` makes `flatpak remotes` and `dconf read` create their own stores (`~/.local/share/flatpak/repo`, `~/.cache/dconf/user`). These are first-use side effects of the tools. On an installed machine both stores already exist.
- VM: uninstall-dryrun-preview's dry run and this lock fix are both waiting for VM access.
