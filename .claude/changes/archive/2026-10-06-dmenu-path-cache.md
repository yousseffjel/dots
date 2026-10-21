# dmenu-path-cache
Date: 2026-10-06
Files: 5 + 2 new (plus slot state) | Lines: +66/-6 tracked, +146 in the new files

## What changed
- `suckless/dmenu/dmenu_path` (pathcache-local patch): it also rebuilds
  `~/.cache/dmenu_run` when `$PATH` differs from the PATH the cache was built
  for, recorded in `$cache.path` after each rebuild. The original
  `stest -dqr -n` condition is kept.
- Rule 5, in one commit:
  - `patches/dmenu-pathcache-20261006-local.diff`, checked byte for byte
    against `git diff HEAD suckless/dmenu/dmenu_path`;
  - a `patches/PATCHES.md` entry with the source (written here, no upstream),
    the bug, the fix and the verification.
- `tests/dmenu-path-cache.sh` (new, 4 checks) uses the real `stest`, compiled
  from the vendored `stest.c`, and skips in yellow without a C compiler.
  - A directory that joins PATH, older than the cache, is listed. An
    unpatched copy (the shipped script minus the new condition, derived by
    sed) misses it.
  - An unchanged PATH is served from the cache, checked with a sentinel cache
    line.
  - A pre-patch cache with no `.path` file is rebuilt once.
- Docs: `CHANGELOG.md` (Fixed, with the `rm ~/.cache/dmenu_run` workaround),
  the `CLAUDE.md` dmenu patch roster (8 → 9), `TESTING.md`.

## Why
VM, 2026-10-06, after flatpak-exports-path: `Mod+p` did not list
`org.xfce.mousepad`. Measured on the VM:
- dwm's own environment (`/proc/<dwm>/environ`) had `~/.config/dwm/bin` and
  both Flatpak `exports/bin` dirs on PATH, so ly does start the session
  through the login zsh and the flatpak-exports-path caveat does not apply
  there;
- `~/.cache/dmenu_run` (13:13:29) was newer than
  `~/.local/share/flatpak/exports/bin` (13:11:02), and `grep -c mousepad` on
  the cache was 0.

Upstream `dmenu_path` only rebuilds for a PATH directory newer than the cache,
so a directory that joins PATH later is never scanned.

## Key Technical Decisions
- **Patch dmenu_path** (user's choice). The rejected alternatives were an
  installer step dropping the cache (helps only when the installer runs) and
  leaving it with a CHANGELOG note. This fix also covers any future PATH
  addition.
- **PATH equality, not a hash.** POSIX sh has no portable hash, the PATH
  string is short, and a reorder costing one rescan is harmless because the
  output is `sort -u`'d.

## Assumptions
- none. The only behaviour change is extra rebuilds.

## Test coverage
- `tests/run-tests.sh`: 41 OK, 0 FAIL (40 → 41 with the new test).
  `tests/lint.sh` clean.
- Mutants on copies:
  - condition removed: the test refuses to run ("could not derive the
    unpatched dmenu_path"), so it can never pass without the patch;
  - `.path` never written: the first-run check fails.
- Audit: Medium+ tier (file count), 0 issues. Reviewer: READY.
- Not on the VM yet: it needs `scripts/install-suckless.sh` to install the new
  `dmenu_path` into /usr/local/bin.

## Follow-ups
- After merge and push, on the VM: `git pull && bash
  scripts/install-suckless.sh`. Until then `rm ~/.cache/dmenu_run` has the
  same effect.
- Recorded here because change logs are immutable:
  - the VM confirmed portal-session-target. After a re-login,
    `graphical-session.target is active` and `the desktop portal answers:
    apps get dark mode`, and Flatpak GNOME Text Editor (GTK4/libadwaita) is
    dark. Before the re-login, the doctor gave the correct "log out and back
    in" hint, since `~/.xinitrc` already had the lines;
  - the first portal attempt failed only because main was unpushed, and the
    fallback `exec dwm` kept the session alive as designed.
- Still unconfirmed in scope E: the Bibata cursor inside a Flatpak window.
