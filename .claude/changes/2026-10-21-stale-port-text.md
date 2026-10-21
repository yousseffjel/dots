# stale-port-text
Date: 2026-10-21
Files: 8 | Lines: +~95/-14

## What changed
- `scripts/install-void.sh`: the header (which `--help` prints) lost the "PORT IN PROGRESS ... does not work on either distro" paragraph; `--only-install` now says xbps packages, not dnf.
- `config/dwm/bin/dwm-record`: the missing-ffmpeg error names `ffmpeg6` (the desktop.lst package), not Fedora's `ffmpeg-free`.
- `scripts/version.sh`: header says it prints the OS (os-release + xbps arch), not "Fedora version".
- `scripts/uninstall-theme.sh`, `scripts/uninstall.sh`: the ordering comments for `uninstall_ly` give the Void reason (it runs before `uninstall_ly_build`, which removes the config.ini of an ly dots built) instead of rpm's `.rpmsave`; the Fedora reason is kept as history.
- New `tests/runtime-text-void.sh`: runs `--help` for every scripts/ file that has a `--help)` case (21, read from the code; sandboxed HOME/XDG) and greps every printed literal in scripts/ and config/*/bin for dnf/rpm/systemctl/ffmpeg-free/"PORT IN PROGRESS".
- CHANGELOG [Unreleased] Fixed line.

## Why
Found reading `dots install --help` on the Void VM six days after the port merged: the help told a Void user the installer did not work, and dwm-record's error pointed at a package name Void does not have.

## Assumptions
- "Fedora" alone stays allowed in printed text (history, e.g. lazygit note); only Fedora-era *tools* are banned. Type B.
- systemd is not in the banned list: printed text mentions it legitimately (no systemd user manager on Void). Type B.

## Test coverage
- The new test failed before the fix (3 help lines + dwm-record) and passes after.
- Mutants on a tar copy: dnf back in --only-install, ffmpeg-free back in dwm-record, systemctl in theme-apply's help header: all caught. (A first M3 did not apply — wrong indent — and was redone.)
- lint passed; full suite 100 OK; reviewer READY.

## Follow-ups
- none
