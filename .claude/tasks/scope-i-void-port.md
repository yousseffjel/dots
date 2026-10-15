# Scope I — Port dots from Fedora Server to Void Linux (glibc)

Opened 2026-10-15 on branch `void` (worktree `.claude/worktrees/void/`).
Size: **Epic** — one sub-task per session.

## DECISION REVERSAL

- Reverses: "Fedora only" (CLAUDE.md header, rule 10) and "Fedora Server is
  the one supported target" (user decision 2026-10-14, `server-target`).
- New target: **Void Linux, glibc, x86_64**, runit init. Fedora support is
  dropped, not kept alongside (user: "instead of fedora").
- `main` stays Fedora until this branch merges; nothing here touches it.

## Research basis (2026-10-15)

- **Package index:** Void's official repodata, downloaded from
  `repo-default.voidlinux.org/current{,/nonfree}/x86_64-repodata`: 14,890
  packages. Every name in `packages/*.lst` was checked against it. This is
  stronger than rule 8's manual page checks, so the port should keep the
  index check as a script (sub-task I-2).
- **Void Handbook** via Context7 (`/websites/voidlinux`), plus
  docs.voidlinux.org/config/session-management.html.
- **Container image:** `ghcr.io/void-linux/void-glibc` (moved from Docker Hub
  in 2023).

## Package map — 128 names: 102 same name, 26 need work

| Fedora name | Void | Note |
|---|---|---|
| `pkgconf-pkg-config` | `pkgconf` | |
| `xorg-x11-server-Xorg` | `xorg-server` (or `xorg-minimal`) | |
| `xorg-x11-xinit` | `xinit` | |
| `glx-utils` | `glxinfo` | dwm-picom's probe |
| `ffmpeg-free` | `ffmpeg6` | `ffmpeg` is a transitional dummy. Void doesn't split out patented codecs, so **no RPM Fusion swap is needed** (confirm HEVC with `ffmpeg -decoders`) |
| `NetworkManager-tui` | — | Assumed to be inside `NetworkManager`; verify `nmtui` is there |
| `pipewire-pulseaudio` | `pipewire` (pulse server built in) | Void wires PipeWire up by hand: config links + autostart. See handbook |
| `pipewire-alsa` | `alsa-pipewire` | |
| `pipewire-jack-audio-connection-kit` | — | Check the `pipewire` jack libs |
| `cascadia-code-nf-fonts` | **not packaged** | Options: `nerd-fonts-symbols-ttf` + a plain face, vendor Cascadia NF under `assets/` (like the Bibata cursor), or the full `nerd-fonts` |
| `google-noto-sans-arabic-vf-fonts`, `google-noto-naskh-arabic-vf-fonts`, `google-noto-sans-fonts`, `google-noto-serif-vf-fonts`, `google-noto-sans-mono-vf-fonts` | `noto-fonts-ttf` | One package covers all; check Arabic is included |
| `google-noto-emoji-fonts` | `noto-fonts-emoji` | |
| `jetbrains-mono-fonts-all` | — | Not packaged; drop or vendor |
| `dnf-plugins-core` | drop | Not needed with xbps |
| `lxpolkit` | `polkit-gnome` (or `lxsession`) | Void still packages polkit-gnome, which Fedora retired |
| `thunar` | `Thunar` | Case differs |
| `ly` | **not packaged** | See decision D1 |
| `dbus-daemon` | `dbus` | Plus a runit service |
| `vim-enhanced` | `vim-huge` or `vim` | |
| `fd-find` | `fd` | **The fd shim goes away** |
| `wget2-wget` | `wget` | |
| `tuned-ppd` | `power-profiles-daemon` | Same D-Bus API, so `dwm-power`'s gdbus calls should carry over |
| sublime-text (Sublime HQ repo) | `sublime-text4` (nonfree) | Needs `void-repo-nonfree`, a repo package, not a third-party repo |
| clipmenu (COPR) | `clipmenu`, `clipnotify` (main) | **COPR exception goes away** |
| intel-ucode, linux-firmware-* | nonfree / main | |

The "same name" matches include the suckless build deps (`libX11-devel` etc.).
I-2 must re-check them as *meaning* the same thing, not just existing.

## What the code assumes (125 files mention Fedora/dnf/rpm/systemd)

Heaviest, by reference count: `scripts/install-pkg-repos.sh` (41),
`tests/pkg-repos.sh` (42), both workflows (~30 each),
`install-pkg-tiers.sh`, `install-services.sh`, `uninstall-repos.sh`,
`install-pkg-dnf.sh`, `drivers-gpu.sh`, `doctor-checks.sh`.

| Area | Fedora / systemd today | Void replacement |
|---|---|---|
| Package install | dnf batched per tier, `--skip-unavailable`, rpm decides what landed | `xbps-install -Sy`. Has no skip-unavailable: pre-filter names with `xbps-query -R`, check what landed with `xbps-query` |
| dnf speed drop-in (SYSFILE) | `/etc/dnf/libdnf5.conf.d` | Drop. Optionally pick a mirror with `xmirror` |
| Third-party repos | COPR, Sublime HQ, RPM Fusion, REPO manifest rows | Only `void-repo-nonfree`; REPO rows shrink to that |
| Services | `systemctl enable ly@tty2`, `usermod` shell | `ln -s /etc/sv/<svc> /var/service/`; needs `dbus`, `elogind` (or turnstile), `NetworkManager`; disable `dhcpcd`/`wpa_supplicant` when NM runs |
| Session target | `dots-session.target` → `graphical-session.target` → `xdg-desktop-portal` | No systemd user manager. Portal runs by D-Bus activation from a session bus: `.xinitrc` needs `dbus-run-session` (or turnstile's bus) and `dbus-update-activation-environment DISPLAY XAUTHORITY` |
| Power menu | `systemctl suspend/reboot/poweroff` | `loginctl suspend\|reboot\|poweroff` (elogind) |
| VM detection | `systemd-detect-virt --vm` (dwm-picom, drivers-detect, spice line) | Not available. Use `/sys/class/dmi/id/sys_vendor`/`product_name` + `/proc/cpuinfo` hypervisor flag (keep the `vm` semantics) |
| Logs | journald | socklog-void (optional) |
| Firmware/microcode | Fedora names | `linux-firmware-{intel,amd,...}`, `intel-ucode` (nonfree), `fwupd` in main |
| CI | `fedora:latest` + oldest-pinned `fedora:43` matrix | `ghcr.io/void-linux/void-glibc` (rolling, so there's no oldest-release pin); `xbps-install -Syu xbps` first |
| Name | `install-fedora.sh`, `dots update` → that | `install-void.sh` (or neutral `install.sh`) |

What carries over unchanged: the suckless sources and builds, the theming
engine, zsh/tmux, symlinks/manifest/uninstall, most `dwm-*` scripts, nsxiv.
The `Adwaita-dark` GTK3 shim may be unnecessary (Void still ships
`gnome-themes-extra`), but keep it; it costs nothing.

## Locked decisions (user, 2026-10-15)

- **D1 Login: build `ly` from source** with its runit service
  (`zig build installexe -Dinit_system=runit`, then `ln -s /etc/sv/ly
  /var/service/` and turn off `agetty-tty2`: `touch /etc/sv/agetty-tty2/down`
  + unlink). Keeps `dots login-theme`.
  **Snag found:** ly's README needs **zig 0.17.x (release, not -dev)**, but
  Void packages **zig 0.13.0**. **Resolved (user, 2026-10-15): pin the
  official zig release tarball by sha256.** I-5 downloads it from
  ziglang.org at build time, verifies it, uses it only to build ly, and
  never installs it system-wide. The version and checksum live next to the
  ly version pin, and a test holds the pair consistent (as
  `tests/linter-pins.sh` does). Build deps: `pam-devel`, `libxcb-devel` (both in main);
  runtime: xorg, `xauth`, `brightnessctl`.
- **D2 Session/seat: elogind.** Enable the `dbus` and `elogind` runit
  services; `loginctl suspend|reboot|poweroff` replaces `systemctl`. Session
  bus: `dbus-run-session` in `.xinitrc` +
  `dbus-update-activation-environment DISPLAY XAUTHORITY`.
- **D3 Font: vendor Cascadia Code NF** under `assets/fonts/` (tarball +
  `.sha256` + license, unpacked by the restore stage and claimed in the
  manifest), the same way as `assets/cursors/`.

## Sub-tasks (one slot each, in order)

- **I-1 Docs & identity:** CLAUDE.md, README, TESTING, record this decision
  reversal; rename `install-fedora.sh`.
- **I-2 Package lists:** remap `packages/*.lst` with the table above; add a
  test that checks every name against a vendored or fetched Void index.
- **I-3 Package engine:** `install-pkg*.sh` dnf → xbps (tiers, retry,
  summaries, SATISFIED_BY), remove the dnf drop-in and the fd shim.
- **I-4 Repos:** shrink `install-pkg-repos.sh`/`uninstall-repos.sh` to
  nonfree; delete COPR, Sublime HQ and RPM Fusion paths and tests.
- **I-5 Services & login:** runit linking (+ uninstall rows), D1, D2,
  login shell.
- **I-6 Session:** `.xinitrc` without systemd user units: D-Bus session,
  portal, `dots_session_end`; update the `session_*report` paste text.
- **I-7 Drivers & VM detection:** replace `systemd-detect-virt`; GPU,
  firmware, microcode names; laptop power via power-profiles-daemon.
- **I-8 Runtime scripts & doctor:** `dwm-powermenu`, `dwm-picom`, `dwm-lock`
  (elogind), every doctor check that asks systemd.
- **I-9 CI:** void-glibc container for build, install, dry-run; linter pins
  unchanged.
- **I-10 Real run:** fresh Void glibc VM end-to-end (the Fedora VM at
  192.168.122.172 is replaced, not reused).
