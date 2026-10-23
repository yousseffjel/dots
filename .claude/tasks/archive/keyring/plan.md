# Plan — keyring

## Goal
Scope K slot 1: an unlocked Secret Service in every dots session. gnome-keyring
is installed; ly's stock PAM file (already placed) unlocks it with the login
password; D-Bus activation starts the secrets component on first use. Flatpak
apps get it through the Secret portal; `dots doctor` asks the keyring itself.

## Scope
- packages/desktop.lst
- config/xdg-desktop-portal/portals.conf
- scripts/doctor*.sh
- tests/doctor-keyring.sh
- docs/*.md
- CHANGELOG.md

## Allowed

## Forbidden
- scripts/install-services-ly*.sh
- scripts/install-session*.sh

## Steps
1. desktop.lst: `gnome-keyring` with its consequence comment (rule 10)
2. portals.conf: `org.freedesktop.impl.portal.Secret=gnome-keyring`, header reworded
3. scripts/doctor-keyring.sh: check_keyring (gdbus: default alias Locked) + doctor.sh wiring
4. tests/doctor-keyring.sh: fake gdbus on PATH, every report branch
5. Docs: where the keyring comes from and what unlocks it; CHANGELOG [Unreleased]
6. Void VM: log in through ly, then `secret-tool store`/lookup with no prompt; doctor ok

## Out of scope
- PAM edits (ly's stock file has the lines); /etc/pam.d/login (startx from a TTY)
- ssh/pkcs11 components; ly autologin (pam_permit, nothing to unlock with)

## Risks
- the activated `--start` does not attach to the PAM daemon → second locked daemon — VM step 6 proves it
- doctor's gdbus call activates the daemon — read-only stays true (no config written); say so in the header
- a user's own ly (not ours) may lack the PAM lines — doctor reports "locked", not "ok"
- secret-tool is libsecret's: check it is in the index before using it in docs
