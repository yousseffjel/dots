# login-shell-canonical-path
Date: 2026-10-05
Files: 6 | Lines: +190/-31 (incl. the new 107-line test)

## What changed
- `scripts/install-services.sh`: `ZSH_BIN` has its directory resolved
  physically (`pwd -P`), so `/usr/sbin/zsh` becomes `/usr/bin/zsh` before it
  reaches `/etc/shells`, `usermod` or the manifest. A new branch treats a
  login shell that is the same file under another spelling (`-ef`) as
  already zsh: it respells it with `usermod` and appends **no** SHELL row.
- `.github/workflows/install-container.yml`: the login-shell assertion
  resolves the directory the same way. The container runs as root with sbin
  first on PATH, so it now fails on the old spelling.
- `tests/login-shell-path.sh` (new): sealed PATH with a sandbox
  `usr/sbin -> bin` pair first; fake sudo/usermod/getent/tee. Four cases:
  fresh bash->zsh, respell of a recorded `/usr/sbin/zsh`, already canonical,
  and `--dry-run`.
- `CHANGELOG.md` (Unreleased, Fixed) and `TESTING.md` (test entry, and the
  container table row for `usermod`).

## Why
The VM install recorded `/usr/sbin/zsh` (MASTER_PLAN called it cosmetic).
It was not: shells were compared as strings, so any later services run under
a bin-first PATH (an SSH session, for one) would `usermod` again and append
`SHELL /usr/sbin/zsh /usr/bin/zsh`. `uninstall_shell` restores the LAST SHELL
row, so uninstall would have "restored" zsh instead of bash.

## Assumptions
- Type B: only the directory is resolved, not the binary (`readlink -f`
  could land on a versioned name). Fedora ships `/usr/bin/zsh` as a file.
- Type B: the respell writes no manifest row. The first row already holds
  the real previous shell.

## Test coverage
- `tests/run-tests.sh`: 29/29 OK. `tests/lint.sh`: passed.
- Mutation testing on scratch copies, 4/4 caught: no dir resolution (7
  fails), respell appending a row (1), no identity branch (1), logical `pwd`
  instead of `pwd -P` (7).
- Reviewer: READY.

## Follow-ups
- VM: `git pull`, then `scripts/install-fedora.sh --only-services`. Expect
  "login shell /usr/sbin/zsh -> /usr/bin/zsh". The stray `/usr/sbin/zsh` line
  the old run appended to `/etc/shells` is harmless; remove it by hand if
  wanted (`sudo sed -i '\|^/usr/sbin/zsh$|d' /etc/shells`).
- Pre-existing: uninstall never removes a line the installer appended to
  `/etc/shells`. Not tracked in the manifest. Left out of scope.
