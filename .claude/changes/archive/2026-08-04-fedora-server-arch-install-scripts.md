# 2026-08-04 — Fedora server + Arch Linux install scripts

## Scope

- `scripts/install-fedora-server.sh` (new)
- `scripts/install-arch.sh` (new)
- `scripts/install-fedora.sh` (one-line fix: fdfind -> fd shim)

## What changed

User asked for two install scripts — one for a fresh Fedora server, one for
Arch Linux — with package names verified online (WebSearch + WebFetch
against packages.fedoraproject.org / archlinux.org) and via Context7
(`/rpm-software-management/dnf5`, `/git_gitlab_archlinux_org/archlinux_alpm_pacman`)
rather than assumed from memory.

Clarified scope first (two ambiguities: `install-fedora.sh` already exists
as a full desktop script from a prior session, and "Arch Linux" could mean
server or desktop): user confirmed the Fedora script should be a **new**
headless server script (parallel to `install.sh`'s Debian-server pattern),
and the Arch script should be a **full desktop** bootstrap (parallel to
`install-fedora.sh`'s desktop pattern).

`scripts/install-fedora-server.sh` (new): headless bootstrap for a fresh
Fedora server — zsh/tmux/git/curl/ca-certificates as hard-required (dnf
install, unguarded), fzf/bat/fd-find/ripgrep/zoxide/eza as best-effort
optional, ZDOTDIR export, `symlinks.sh`, zinit/TPM bootstrap, chsh to zsh,
`--with-suckless` opt-in (off by default — no X11 on a server) that defers
to `install-suckless.sh`.

`scripts/install-arch.sh` (new): full Arch desktop bootstrap — `pacman
-Syu` (avoids the ArchWiki-documented "partial upgrade" problem before
installing anything new), `git`/`zsh` as hard-required, `base-devel` group
with an individual-package fallback note, a ~55-package best-effort loop
(X11/display server, fonts/theming, desktop utilities, dev stack), ZDOTDIR,
`symlinks.sh`, zinit/TPM, chsh, `ly.service` enable, and building
dwm/st/dmenu/dwmblocks/slock by default via `install-suckless.sh`
(`--skip-suckless` to opt out) — mirrors `install-fedora.sh`'s desktop
defaults.

`scripts/install-fedora.sh`: added the same `fdfind -> ~/.local/bin/fd`
shim `install.sh` already has for Debian/Ubuntu. Research surfaced that
Fedora's `fd-find` rpm ships its binary as `fdfind` too (name clash with an
unrelated package, same root cause as Debian) — the prior session's script
installed `fd-find` but never shimmed it, so `command -v fd` checks in the
zsh/tmux configs would have silently failed on Fedora. Also added the same
shim to the new `install-fedora-server.sh`.

## Key technical decisions

- **`git`/`zsh` pulled out of the best-effort loop in `install-arch.sh`.**
  Caught by the independent reviewer: folding them into the best-effort
  `PACKAGES` array meant a transient pacman failure on either would be
  silently "skipped," then hard-abort the unguarded `git clone` calls
  (zinit/TPM bootstrap) later under `set -e` — confusing and inconsistent
  with how `install.sh`/`install-fedora-server.sh` already treat their
  own required packages. Split into a `REQUIRED=(git zsh)` array installed
  up front, hard-fail, matching the existing convention.
- **`bibata-cursor-theme` dropped from `install-arch.sh`'s `PACKAGES`.**
  Verified via archlinux.org it's AUR-only (0 official matches) — no AUR
  helper is bootstrapped here (that's a separate trust decision), so the
  script prints a closing reminder instead of silently never installing it.
- **`fd`/`zoxide` package names differ across the three ecosystems** and
  were verified individually: Debian/Ubuntu `fd-find` -> `fdfind` binary
  (existing shim in `install.sh`), Fedora `fd-find` -> `fdfind` binary (new
  shim, this change), Arch `fd` -> `fd` binary (no clash, no shim needed).
- **`pacman -Syu` (full system upgrade) before installing new packages**,
  not just `-Sy` (sync only). This is the ArchWiki-documented safe pattern
  — installing on top of a stale local package database is an unsupported
  "partial upgrade." Disclosed as a trade-off below since it does touch the
  whole system, not just the packages this script cares about.

## Assumptions made

- **Type A resolved via user confirmation.** Asked directly: (1) should the
  Fedora server script be new/separate from the existing desktop
  `install-fedora.sh`, and (2) should the Arch script be server or desktop.
  User answered "fresh Fedora server" (new headless script) and "full
  desktop" respectively.
- **Type C — package names taken from live web verification, not
  re-checked against actual Fedora/Arch installs** (this machine is Arch,
  but not the target release/mirror state at run time). The best-effort
  per-package loop is the safety net if a name has drifted since
  verification. *If wrong:* rerun the script; yellow "skipped" lines name
  the exact package to fix.
- **Type C — `install-arch.sh` enables `ly.service` but leaves `getty@tty1`
  alone**, matching `install-fedora.sh`'s identical decision for the same
  reason (depends on the user's existing layout).

## Verification

`bash -n` on all four touched/new scripts (`install-fedora-server.sh`,
`install-arch.sh`, `install-fedora.sh`, `install-suckless.sh` — unchanged
this session, sanity-checked only). `--help` output manually inspected for
both new scripts to confirm the `sed` header-extraction ranges are exact.
Independent `reviewer` subagent pass: found and the one real gap (the
git/zsh best-effort issue above) before returning `READY`. Not run on
actual Fedora or Arch hardware — no such machine available in this
session.

## Trade-offs

- `install-arch.sh`'s `pacman -Syu` upgrades the entire system, not just
  installs new packages — appropriate for a script that only makes sense
  on a machine being freshly bootstrapped, but worth knowing before running
  it against an Arch box with meaningful existing state.
- Package-name verification was web research, not a live `dnf`/`pacman`
  query (no Fedora machine, and this Arch machine's live state doesn't
  prove the *script's* assumptions) — the best-effort loops are the
  intended safety net, not a guarantee every name resolves.

## Next steps

1. Run `scripts/install-fedora-server.sh` on a fresh Fedora server and
   `scripts/install-arch.sh` on a fresh Arch box to confirm every package
   name still resolves and the flows complete end-to-end.
2. Optional: bootstrap an AUR helper (yay/paru) in `install-arch.sh` if the
   user wants `bibata-cursor-theme` installed automatically rather than as
   a manual reminder.
3. Optional: add `zoxide` to `install-fedora.sh`'s (desktop) optional list
   for parity — it's in both new scripts' lists but was absent from the
   existing desktop script and wasn't in scope to touch further here.
