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

### I-2 outcome (2026-10-15) — where the table above was wrong or open

Checked by reading the downloaded `.xbps` file lists:
- **`xorg-server` alone has no input driver**, so keyboard and mouse would be
  dead. Mapped to `xorg-minimal` (= xorg-server + xauth + xinit +
  xf86-input-libinput), plus **`mesa-dri`** for glamor/GLX.
- **lxpolkit is in `lxsession`** (`/usr/bin/lxpolkit`), so the autostart line
  is unchanged. polkit-gnome would have needed a libexec path.
- nmtui is in `NetworkManager` (moved to desktop.lst for the NET click). The
  Noto Arabic pair and Sans/Serif/Mono are all in `noto-fonts-ttf`.
  Emoji data is at the same path dwm-emoji reads.
- **ffmpeg6 is the full build** (configure line in libavcodec.so.60: GPL,
  x264, x265, vaapi, no disabled decoders). The RPM Fusion reason is gone.
- jack → `libjack-pipewire`. `dbus` and `elogind` added to desktop.lst
  (D2). clipmenu/clipnotify added to desktop.lst. `starship` added to
  extra.lst (Void packages it).
- **`brightnessctl` is built without logind**: it writes /sys through its
  udev rule for the `video` group (Void installer default; D4).

Handed on to later sub-tasks:
- **I-2b: vendor Cascadia Code NF (D3).** ✅ Done 2026-10-15:
  `assets/fonts/CascadiaCodeNF-2407.24.tar.xz` (1.2 MB, a reproducible repack
  of the two variable NF TTFs from the 150 MB upstream zip). Extraction is
  shared with the cursor (`install-restore-vendored.sh`). No fc-cache: the
  symmetry test showed it leaves `~/.cache/fontconfig` behind.
- **I-3:** delete the upstream starship installer and the fd shim (both now
  packaged). Delete SATISFIED_BY (only ffmpeg-free used it; the doctor test
  cases are already gone).
- **I-4:** `sublime-text4` from nonfree, installed after
  `void-repo-nonfree`.
- **I-6:** pipewire, pipewire-pulse and wireplumber have no systemd user
  units on Void. The session must start them (the handbook's autostart
  approach).
- **I-7:** drivers-laptop.sh still enables tuned/tuned-ppd services. Move it
  to power-profiles-daemon's runit service (the laptop test checks only the
  package for now).
- **Open, low priority:** Void packages nsxiv 34 (same version as the
  vendored copy) and `xcolor`. Either could replace a vendored build or a
  script, but both work as they are. Ask before changing either.

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

- **D4 User groups: the installer adds them, not the Void installer.** The
  user installs Void with the installer's **default** group selection
  (`wheel`, `audio`, `video`, `floppy`, `cdrom`, `optical`, `kvm`, ...), so
  group membership is reproducible from the script instead of depending on
  boxes clicked in one session. **`wheel` is the one hard prerequisite.** The
  script calls `sudo`, which Void grants to `wheel` (the installer's
  default), so `install-pre.sh` must fail with a clear message when the user
  is not in `wheel`. I-5 then runs
  `sudo usermod -aG network,bluetooth,kvm "$USER"`. That is idempotent, so it
  satisfies rule 1. Each group has a reason:
  - `network`: Void's NetworkManager polkit rules let only this group
    manage connections without root (`nm-applet`, `nmtui`).
  - `bluetooth`: bluez on Void lets this group drive the adapter
    (`blueman`, `bluetoothctl`).
  - `kvm`: libvirt/QEMU guests; harmless on a box without them.
  - **Not added:** `disk`, `kmem`, `sys`, `tty` (effectively root),
    `_seatd` (D2 picked elogind, not seatd), `dialout`/`lp`
    (add them by hand for serial devices or printers). `storage`/`plugdev`
    are not needed because elogind + udisks2 polkit already serve
    `udiskie` in an active session.
  - **Ordering:** a group must exist before `usermod -aG` can add the user
    to it, and `bluetooth` is created by the `bluez` package. So the step
    runs in the services stage, after packages. A group that is still
    missing gets a yellow warning, never a hard failure.
  - **New groups need a re-login.** The stage prints a yellow reminder
    instead of assuming they are already live. `dots doctor` should check
    `id -nG` against this list (I-8).
  - Uninstall does **not** remove the groups (no manifest row). Taking
    `network` away from a user can lock them out of their own network
    config. Record this as a documented leftover in
    `tests/install-uninstall-symmetry.sh`'s terms.
  - Verify the three names against Void's `base-files` `/etc/group` and
    bluez's `system_groups` in I-5 before shipping. They come from the
    handbook and package metadata, not from a live Void box.

### I-3 outcome (2026-10-15)

- xbps behaviour probed with the real **xbps-static 0.60.7** in a scratch
  root (`-r`), not guessed:
  - one unknown name aborts the whole transaction (exit 2), so names are
    filtered with `xbps-query -R` first;
  - re-installing is exit 0, but prints an `ERROR:` line;
  - `xbps-remove` of a name that is not installed fails the whole call
    (exit 2);
  - `-Syu xbps` and `-yu` are exit 0 when there is nothing to do.
- **User decision: a full upgrade on every run** (`-Syu xbps`, then `-yu`;
  Void has no partial upgrades). Chosen over upgrading only on the first
  install, and over warning only.
- Removed: the dnf speed drop-in (+ its test), SATISFIED_BY, the starship
  upstream script, and the fd shim. Uninstall uses `xbps-remove -Ry` on rows
  still installed (new test). Doctor's package check uses `xbps-query`,
  gated on os-release `ID=void`. `version.sh`'s `fedora_version` is now
  `os_version` (no consumers). The pre-stage checks for xbps and notes musl.
- Still dnf, by design, until their sub-task:
  - `install-pkg-repos.sh` and `uninstall-repos.sh` (I-4);
  - `drivers-*.sh` and `doctor-drivers.sh` (rpm) (I-7);
  - `suckless/dwmblocks/scripts/dwm-updates`, the updates block (**I-8**:
    `xbps-install -nu`, no network);
  - `install-services.sh`'s `rpm -q ly` (I-5);
  - CI and `tests/ci-build-deps.sh` (I-9).

## Sub-tasks (one slot each, in order)

- **I-1 Docs & identity:** CLAUDE.md, README, TESTING, record this decision
  reversal; rename `install-fedora.sh`.
- **I-2 Package lists:** ✅ done 2026-10-15 (see I-2 outcome above); remap `packages/*.lst` with the table above; add a
  test that checks every name against a vendored or fetched Void index.
- **I-2b Font asset:** ✅ done 2026-10-15; vendor Cascadia Code NF under `assets/fonts/` (D3), restore + manifest + uninstall, drop the fontconfig-stack pending entry.
- **I-3 Package engine:** ✅ done 2026-10-15 (see I-3 outcome); `install-pkg*.sh` dnf → xbps (tiers, retry,
  summaries, SATISFIED_BY), remove the dnf drop-in and the fd shim.
- **I-4 Repos:** ✅ done 2026-10-15 (nonfree + sublime-text4; `pkg_ensure` added to the tiers for I-7's drivers_pkg to reuse); shrink `install-pkg-repos.sh`/`uninstall-repos.sh` to
  nonfree; delete COPR, Sublime HQ and RPM Fusion paths and tests.
- **I-5 Services & login:** ✅ done 2026-10-15 (ly v1.4.1 + zig 0.16.0, built and staged for real; see the change log); runit linking (+ uninstall rows), D1, D2, D4 (user groups),
  login shell.
- **I-6 Session:** ✅ done 2026-10-15 (dbus-run-session re-exec, portal via D-Bus activation, pipewire + LINK rows; see the change log); `.xinitrc` without systemd user units: D-Bus session,
  portal, `dots_session_end`; update the `session_*report` paste text.
- **I-7 Drivers & VM detection:** replace `systemd-detect-virt`; GPU,
  firmware, microcode names; laptop power via power-profiles-daemon.
- **I-8 Runtime scripts & doctor:** `dwm-powermenu`, `dwm-picom`, `dwm-lock`
  (elogind), every doctor check that asks systemd; a D4 group check (`id -nG`).
- **I-9 CI:** void-glibc container for build, install, dry-run; linter pins
  unchanged.
- **I-10 Real run:** fresh Void glibc VM end-to-end (the Fedora VM at
  192.168.122.172 is replaced, not reused).
