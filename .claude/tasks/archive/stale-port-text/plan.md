# Plan — stale-port-text

## Goal
`install-void.sh --help` still tells users "PORT IN PROGRESS ... this script
does not work on either distro" (false since the 2026-10-15 merge) and that
--only-install installs "dnf packages". dwm-record's missing-ffmpeg error
names Fedora's ffmpeg-free (Void: ffmpeg6). version.sh's header says "Fedora
version"; uninstall-theme.sh justifies an ordering with rpm's .rpmsave.

## Scope
- scripts/install-void.sh
- config/dwm/bin/dwm-record
- scripts/version.sh
- scripts/uninstall-theme.sh
- tests/runtime-text-void.sh
- CHANGELOG.md

## Allowed

## Forbidden

## Steps
1. tests/runtime-text-void.sh: rendered --help of every header-help script
   and every printed string literal carry no dnf/rpm/systemctl/systemd/
   ffmpeg-free/"PORT IN PROGRESS" (history words like "Fedora" allowed).
2. install-void.sh: drop the PORT paragraph; --only-install says xbps.
3. dwm-record: ffmpeg6; version.sh header: OS version.
4. uninstall-theme.sh: the ordering comment states the Void reason.
5. CHANGELOG line.

## Out of scope
- History paragraphs (lazygit/Bibata/clipmenu notes) — accurate as history.

## Risks
- A legit future message naming systemd — the test says why it fails.
