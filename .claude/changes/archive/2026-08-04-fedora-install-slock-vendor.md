# 2026-08-04 — Fedora install script + vendor slock 1.7

## Scope

- `suckless/slock/**` (new vendored tree)
- `scripts/install-suckless.sh`
- `scripts/install-fedora.sh` (new)

## What changed

User supplied a "final, streamlined installation manifest for Fedora" (package
lists across core system/display server, shell/interface, fonts/theming,
desktop utilities, dev stack, plus `ly` as display manager and `slock` as
screen locker, Node.js deferred to `nvm`, `mpv` dropped). Turned it into a
runnable, idempotent script following the existing `install.sh` /
`install-macos.sh` conventions.

Vendored **slock 1.7** (latest upstream tag, `b04f4d0`) into `suckless/slock/`,
matching the dwm/st/dmenu pattern: plain source tree, no patches (none were
requested), `.gitignore` covering `config.h`/`*.o`/`slock`. Built clean with
the project's own flags, zero warnings; verified the resulting binary links
against `libcrypt`, `libX11`, `libXext`, `libXrandr` as expected.

`scripts/install-suckless.sh`:
- `PROGRAMS` now includes `slock`.
- `install_deps()` gained a `dnf` branch (Fedora wasn't supported before —
  only `pacman`/`apt-get`), and all three branches now also install
  `libXext`/`libXrandr`/libcrypt headers, which slock needs but dwm/st/dmenu
  don't.
- Closing hint lines mention `slock`.

`scripts/install-fedora.sh` (new): installs the manifest's package list via
`dnf`, sets `ZDOTDIR`, symlinks dotfiles, bootstraps zinit/TPM, sets zsh as
the login shell, enables `ly.service`, then runs `install-suckless.sh`
(building dwm/st/dmenu/dwmblocks/slock) by default.

## Key technical decisions

- **Package installs are best-effort, one at a time.** A single `dnf install`
  call with ~55 packages aborts the whole transaction if any one name is
  wrong for the running Fedora release; looping mirrors the `OPTIONAL`
  best-effort pattern already used in `install.sh`/`install-macos.sh`, but
  applied to the *entire* list here — this manifest doesn't have a
  server-critical vs. nice-to-have split the way `install.sh` does.
- **`C Development Tools and Libraries` group install tried two ways.**
  `dnf group install` (dnf5 syntax) is tried first, falling back to
  `dnf groupinstall` (dnf4 syntax) — the individual `gcc`/`make` packages in
  `PACKAGES` still cover the toolchain if both fail.
- **Suckless build deps are NOT skipped when `install-fedora.sh` calls
  `install-suckless.sh`.** `PACKAGES` above only has the libs dwm/st already
  needed (`libX11-devel`, `libXft-devel`, `libXinerama-devel`, etc.);
  `install-suckless.sh`'s own `dnf` branch is what actually installs
  `libXext-devel`/`libXrandr-devel`/`libxcrypt-devel`/`ncurses` for slock and
  st. Passing `--skip-deps` would have silently broken the slock/st build.
- **`ly.service` is enabled, but getty units are left alone.** Whether
  `getty@tty1` needs disabling depends on the user's existing layout — the
  script prints a reminder instead of guessing.

## Assumptions made

- **Type A resolved via user confirmation — vendor slock now, not defer it.**
  The manifest said slock would be "built directly from your suckless source
  repository alongside dwm," but no slock source existed in `suckless/` yet
  (unlike dwm/st/dmenu, which were vendored in dedicated prior commits). Asked
  the user; they chose "vendor slock now," matching the existing
  dwm/st/dmenu pattern. *If wrong:* `git rm -r suckless/slock` and revert the
  `PROGRAMS`/dnf-deps edits in `install-suckless.sh`.
- **Type B — Node.js/nvm is a manual post-step, not scripted.** The user's
  own manifest text frames it that way ("install nvm post-setup via its
  official script"), and nvm's installer wants to append lines to zsh rc
  files that are symlinks into this repo — auto-running it risks dirtying
  tracked config. *If wrong:* add an idempotent `git clone` of `nvm-sh/nvm`
  into `~/.nvm` (matching the zinit/TPM bootstrap pattern already in the
  script) and drop the reminder line.
- **Type B — suckless build defaults ON in `install-fedora.sh`**, unlike
  `install.sh`'s `--with-suckless` opt-in for Debian/Ubuntu. The Fedora
  manifest already lists Xorg + the X11 devel headers unconditionally, so
  this script only makes sense for a desktop target. *If wrong:* flip the
  default and rename the flag to `--with-suckless` for symmetry with
  `install.sh`.
- **Type C — slock's `config.def.h` left vanilla, unlike dmenu's themed
  rewrite.** The manifest didn't ask for lock-screen theming, only that
  slock exist. *If wrong:* match the accent colors from
  `suckless/dwm/config.def.h`, following the same approach used for dmenu.
- **Type C — package names taken as given from the user's "final" manifest,
  not re-verified against a live Fedora repo** (this machine is Arch, no
  `dnf` available to query). The best-effort install loop is the safety net
  if any name has drifted on the current Fedora release. *If wrong:* rerun
  the script; each yellow "skipped" line names the exact package to fix.

## Verification

`bash -n` on both `install-fedora.sh` and the edited `install-suckless.sh`.
slock built locally (`make clean && make`): zero warnings under
`-std=c99 -pedantic -Wall -Os`; `ldd slock` confirms links against
`libcrypt.so.2`, `libX11.so.6`, `libXext.so.6`, `libXrandr.so.2`. Not
runtime-tested end-to-end on actual Fedora hardware — no Fedora machine
available in this session.

## Trade-offs

- The best-effort package loop means a typo'd package name fails silently
  (yellow, not red) rather than stopping the script — intentional, but means
  the user should scan the yellow lines rather than assume "exit 0 = every
  package landed."
- `install-fedora.sh` duplicates `libX11-devel`/`libXft-devel`/etc. between
  its own `PACKAGES` array and `install-suckless.sh`'s `dnf` branch. Harmless
  (dnf no-ops on already-installed packages) but is redundant install work on
  every run.

## Next steps

1. Run `scripts/install-fedora.sh` on real Fedora hardware to confirm every
   package name in the manifest still resolves on the current release.
2. Confirm `ly` actually replaces the login prompt on next boot, and that
   `slock`'s setuid bit (`chmod u+s`, set by its own `make install`) survives
   on Fedora's SELinux policy — SELinux can restrict setuid binaries in ways
   Arch/Debian don't; worth a manual `slock` invocation test.
3. Optional: theme `suckless/slock/config.def.h` to match dwm's palette, the
   way dmenu's was, if desired later.
