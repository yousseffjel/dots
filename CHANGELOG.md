# Changelog

All notable changes to dots are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

What each kind of version bump means for an existing install is defined in
`README.md` under **Versioning**. `VERSION` is the source of truth: it is
what the install manifest records and what `scripts/migrate.sh` compares.
`tests/changelog-version.sh` fails the build when the newest released
heading below and `VERSION` disagree. How to cut a release is in
`CONTRIBUTING.md`.

The day-to-day record is `.claude/changes/`: one dated log per task, with the
reasoning. This file is the user-facing summary of those logs, not a copy.

## [Unreleased]

### Added

- **Install Void itself from the live ISO** (first part of scope J).
  `scripts/install-live.sh`, run as root on the Void live ISO against a root
  you have partitioned and mounted at `/mnt`, installs base-system with the
  `linux` kernel and `linux-lts` as a backup. It sets the hostname,
  timezone, keymap and locale, creates your user in wheel with sudo, and
  installs GRUB for UEFI or BIOS. It asks with `dialog` menus, or reads
  `--answers FILE` for an unattended run; `--dry-run` writes nothing.
  Partitioning, encryption and running the dotfiles installer before the
  reboot come in later parts.
- **Notification centre.** `Super` + `Ctrl` + `n`, or a left-click on the
  bell in the bar, opens dunst's history as a list under the right end of the
  bar. Open a notification (shows it again and opens its link) or delete it,
  clear them all, or switch focus mode. dmenu gained `-x`, `-y` and `-z` to
  place it there.
- **Focus mode button.** The bar always shows a bell with the number of past
  notifications, or `FOCUS` while notifications are held back. Right-click
  switches focus mode. It replaces the `DND` block, which appeared only while
  paused.

### Fixed

- **A wallpaper or theme change no longer ends focus mode or empties the
  notification centre.** The theming engine used to restart dunst; it now
  reloads dunst's settings in place and keeps focus mode on.
- **Volume, microphone and brightness pop-ups no longer fill the
  notification centre.** They still show; they just do not go into history.
- **The volume block shows the real level after login.** On Void, PipeWire
  starts next to dwm, so the block was drawn before WirePlumber restored the
  saved volume and kept the old figure until the first volume key. A small
  watcher (`dwm-audiowatch`, started from `autostart.sh`) now follows
  PipeWire's events and redraws the volume and mic blocks. An existing
  `autostart.sh` is yours and is not rewritten: the installer prints the
  line to add.

### Changed

- **The target is now Void Linux (glibc), not Fedora Server.** The installer
  is renamed `scripts/install-void.sh`. The port is in progress: until it
  lands, the installer works on neither distro.
- **Package lists use Void names**, checked against a snapshot of Void's repo
  index by a new test (`tests/void-pkgnames.sh`). clipmenu and starship now
  come from the distro's own repo, and the full ffmpeg build replaces
  ffmpeg-free plus the RPM Fusion swap.
- **Cascadia Code NF ships with dots.** Void does not package it, so the two
  variable Nerd Font faces are vendored in `assets/fonts/` and installed to
  `~/.local/share/fonts/`. `dots uninstall` removes them again.
- **Packages install with xbps.** Every run first syncs, updates xbps, and
  upgrades the whole system (`xbps-install -Su`), because Void does not
  support partial upgrades. Then each tier installs in one transaction.
  `dots uninstall` removes recorded packages with `xbps-remove -R`, skipping
  any you already removed. `dots version` reports `os_version` instead of
  `fedora_version`.
- **The editor comes from Void's nonfree repository.** The installer enables
  it (`void-repo-nonfree`) and installs `sublime-text4`. `dots uninstall`
  disables nonfree again only if the installer enabled it and nothing
  installed still comes from it.
- **Services run under runit.** The installer enables `dbus`, `elogind`,
  `NetworkManager` and `bluetoothd` (turning off `dhcpcd`/`wpa_supplicant`
  once NetworkManager is on), and adds you to `network`, `bluetooth` and
  `kvm`. It stops early, saying how to fix it, if you are not in `wheel`.
- **ly is built from source**, pinned to v1.4.1 and built with zig 0.16.0
  (an official tarball checked by sha256, used for the build only). It takes
  over tty2 from its getty; tty1 stays a rescue login. `dots uninstall`
  removes the files it built and gives tty2's getty and `dhcpcd` back.
- **The session starts its own D-Bus bus and PipeWire.** `~/.xinitrc`
  re-runs itself under `dbus-run-session`, hands the display to D-Bus
  activation (the desktop portal starts on demand), and starts `pipewire`,
  which brings up WirePlumber and the PulseAudio server through two links in
  `~/.config/pipewire`. All of it stops when you log out. An existing
  `~/.xinitrc` is told which lines to add (`docs/THEMING.md`, Desktop
  portal).
- **`dots drivers` uses Void's packages.** Video decoding comes from
  `intel-media-driver`, `libva-intel-driver` or `mesa-vaapi` in the main
  repo, with no third-party repo. Missing firmware is looked up in the
  `linux-firmware*` packages' file lists. Microcode is `intel-ucode` (nonfree)
  or `linux-firmware-amd`, with the initramfs rebuilt. NVIDIA is still only
  reported, now with Void's `nvidia*` packages. Laptops get
  `power-profiles-daemon` and its runit service instead of tuned. Virtual
  machines are recognised from the CPU's `hypervisor` flag, and get the SPICE
  agent's `spice-vdagentd` service enabled.
- **The power menu and status bar speak Void.** Suspend, reboot and shut
  down go through elogind's `loginctl`. The `UPD` block counts pending
  updates with a local `xbps-install -nu` (no network), and right-click runs
  `sudo xbps-install -Su`. fastfetch shows the Void logo. `dots doctor`
  says when you are missing one of the `network`, `bluetooth` or `kvm`
  groups, or were added to it but have not logged in again.
- **Tested end to end on a Void Linux virtual machine**: install, login
  through ly, the session, audio, the portal, power actions and `dots
  doctor`. `docs/HARDWARE.md` now covers a VM's screen and login-screen
  size.
- **CI runs in Void's own image** (`ghcr.io/void-linux/void-glibc-full`):
  the suckless builds, dwm under Xvfb, the ASan check, a live check of every
  package name, and the full installer. Runit services are linked into the
  default runsvdir when `/var/service` is not live (a container or chroot),
  and microcode rebuilds the initramfs of the installed kernels.
- `Super` + `Ctrl` + `n` opens the notification centre. It used to re-show
  the last closed notification; **open** in the centre does that for any of
  them.
- `jq` and `xdg-utils` are in the desktop package tier: the notification
  centre needs `jq` to list notifications and `xdg-open` to open their links.
  A failed install of either is now reported in red.

- **Faster installs.** Each package tier now installs in one dnf transaction
  instead of one per package (about 130 dnf runs on a fresh install), with
  dnf's progress shown as it downloads. If the transaction fails, packages are
  retried one at a time, so the failure is still named.
- **dnf drops slow mirrors.** The installer writes
  `/etc/dnf/libdnf5.conf.d/30-dots-speed.conf`: fastest mirror, 10 parallel
  downloads, and a 20 KiB/s floor. Before, a mirror sending 3 KiB/s held a
  fresh install for an hour. `dots uninstall` removes the file while it is
  unedited. Repository metadata is refreshed once, up front.
- **CI install job times out at 20 minutes** instead of 90. With batched
  installs a leg takes about 3 minutes, so a hung run now fails in 20 minutes
  rather than holding a runner for an hour and a half.

### Removed

- `dots-session.target`, the systemd user unit that started
  `graphical-session.target` for the portal. Void has no systemd user
  manager; the session bus does that job.
- The clipmenu COPR, Sublime HQ's rpm repo and RPM Fusion (with its ffmpeg
  swap). Void's main repo has clipmenu and a full ffmpeg.
- The dnf speed settings file (`/etc/dnf/libdnf5.conf.d/30-dots-speed.conf`),
  the starship download script and the `fd` shim. Void packages starship and
  fd under their real names, and xbps has no speed setting to tune.

- The `C Development Tools and Libraries` group install. It failed on every
  Fedora 44 run without saying why; `packages/build.lst` already declares the
  toolchain.

## [0.4.0] - 2026-10-14

### Added

- **Virtual machines are recognised.** `dots drivers` and `dots doctor` now
  report a VM as `vm (kvm)` rather than an unknown chassis. A VM always gets
  desktop behaviour, even if the hypervisor exposes a laptop chassis or a
  battery.

### Changed

- **Fedora Server is the supported target.** The docs promised Fedora
  Workstation too, but it was never run, and nothing reconciles its GNOME
  login screen (GDM) with dots' ly. The installer now prints a note when it
  finds GDM enabled, then carries on.
- **picom's backend is chosen by `dwm-picom`, and a VM always gets
  `xrender`.** The choice used to be a probe pasted into your `autostart.sh`,
  so later fixes could never reach an existing install, and a VM with 3D
  passed through still got `glx`, the backend that froze the screen on the
  first VM install. `dwm-picom` now decides: xrender in any VM, glx only on
  bare-metal hardware 3D. It is updated with dots. `dots doctor` warns when
  picom runs a backend this machine should not use. An existing
  `autostart.sh` is told to replace its picom lines with `dwm-picom &`.

### Fixed

- **Every `dwm-*` command answers `--help`.** Eight of them (`dwm-apps`,
  `dwm-clipmenu`, `dwm-display`, `dwm-emoji`, `dwm-keys`, `dwm-powermenu`,
  `dwm-theme`, `dwm-wallpaper`) opened their menu instead, and
  `dwm-colorpicker --help` failed without ImageMagick. Each now prints what
  it does and its key.
- **The last false "installed:" lines are gone from re-runs.** The clipmenu
  and Sublime Text steps still reinstalled and announced `clipmenu`,
  `clipnotify` and `sublime-text` every time, and re-enabled the clipmenu
  COPR, printing Fedora's "Enabling a Copr repository" notice. Each is now
  skipped when it is already there.

## [0.3.0] - 2026-10-14

### Added

- **Power profiles on laptops.** `Super+Shift+p`, or `profile` in the power
  menu, switches between power-saver, balanced and performance through
  `tuned-ppd`. It is installed, with `tuned` enabled so the choice survives
  a reboot, on laptops only. On a desktop the key explains why nothing
  happens.
- **Laptop touchpads tap to click.** On a laptop, `dots drivers` installs
  touchpad settings for Xorg: tap-to-click, natural scrolling, palm
  rejection while typing, and a two-finger click as a right-click. They
  apply to touchpads only, from the next login. An edited copy is never
  overwritten or uninstalled. `dots doctor` checks it.
- **A battery block for laptops.** The bar shows `BAT 84%`, with `+` while
  charging, and warns once at 15 % and once (critical) at 5 % on battery.
  Left-click shows the time left. It is invisible on a desktop. No new
  daemon: the block's own 60-second refresh does the checking.
- **Laptops are supported, and dots tells them apart from desktops.**
  `dots drivers` and `dots doctor` now say whether this machine is a laptop
  or a desktop, from the firmware's chassis type or a system battery. On a
  laptop, the brightness keys dim the real backlight (`brightnessctl`, which
  is installed on laptops only) and the bar shows `BL`. A desktop keeps
  xrandr gamma and the `GAMMA` label, exactly as before. Battery, touchpad
  and power-profile support follow. See `docs/HARDWARE.md`.
- **`dots drivers` installs what your hardware needs.** It reads the GPUs,
  the CPU and this boot's kernel log, and installs the matching video
  decoding driver (Intel old or new, AMD's freeworld mesa), any firmware a
  driver failed to load, CPU microcode and fwupd. The installer runs it too,
  so `intel-media-driver` is no longer installed on machines without an
  Intel GPU. An NVIDIA card is identified and the exact commands for its
  driver branch are printed, Secure Boot steps included, but the driver is
  never installed for you. `dots doctor` reports the same things, including
  pending firmware updates. See `docs/HARDWARE.md`.
- **Arabic renders properly next to English.** Noto Sans Arabic and Noto
  Naskh Arabic are installed, and a new `~/.config/fontconfig` (linked from
  `config/fontconfig/`) puts them directly behind the Latin faces, so Arabic
  in GTK apps, the browser and Flatpak apps uses them instead of whatever the
  system ranks next. dwm's window title and every dmenu menu now join Arabic
  letters and lay them out right to left (new `bidi` patches, built against
  FriBiDi). Terminals still show Arabic unjoined; `docs/FONTS.md` explains
  why, and covers the whole font stack.
- **Default apps for images, video and text.** Images open in **nsxiv**,
  built from source with the other suckless programs (Fedora does not package
  it) and themed from the wallpaper. Video and audio open in **mpv**, with a
  config for HDR tone-mapping and hardware decoding. Text and code open in
  **Sublime Text**, installed from Sublime HQ's signed repo, with nvim kept
  as the fallback. Firefox still opens web pages and PDFs, and file-roller
  still opens archives.
- **HEVC and HDR video play.** Fedora's own ffmpeg cannot decode HEVC, so the
  installer enables RPM Fusion free and nonfree, swaps in RPM Fusion's
  ffmpeg, and installs `intel-media-driver` for Intel hardware decoding.
  `dots uninstall` swaps ffmpeg back and removes each repository it added
  once nothing installed still comes from it.
- **An existing install picks up new default apps** on its next re-run or
  `dots update`, as long as you never edited `~/.config/mimeapps.list`.

- **A wallpaper collection, and a new install opens on one of them.** The
  installer shallow-clones the 189-image wallpaper repo (about 400 MB to
  download, 780 MB on disk) into
  `wallpapers/dots/` in your pictures folder, and `dots update` pulls new
  images. A new install starts on a random one instead of the generated
  gradient. Uninstall removes the clone only while it is unchanged: an image
  you added keeps the folder. Run the installer with `DOTS_WALLPAPER_REPO=`
  to skip the download.

- **`dots wallpaper --login-random on` picks a new wallpaper at every login.**
  Off by default; `off` and `status` do what they say. An `~/.xinitrc` from an
  earlier install needs three lines, which the command prints.

- **`Super` + `space` opens a launcher that lists applications, not commands.**
  `dwm-apps` shows the installed `.desktop` entries by name, like rofi's drun,
  instead of `dmenu_run`'s every binary on `PATH`. It hides entries marked
  `NoDisplay` or `Hidden` and opens `Terminal=true` apps in alacritty. A
  `dots-st.desktop` keeps the st fallback terminal reachable from it.

- **The ly login screen follows the theme.** Its border takes the console
  colour nearest the active static theme's accent (the same accent as dwm's
  focused border — a Linux console has 16 colours, so a theme's exact hex
  would draw white), with a big clock and no version string. Written at install and on every
  `dots theme <name>`, which asks for sudo in a terminal and, from the theme
  keybinding, sends a notification instead of hanging on a prompt. `dots
  login-theme` applies it by hand; `dots uninstall` restores ly's own values.

### Changed

- **The GTK UI font is now Noto Sans 10** (was JetBrains Mono 10) in all
  four themes. Terminals, the bar and dmenu stay on Cascadia Code NF. Run
  `dots theme <name>` to apply it to an existing install.

- **Keybindings remapped.** Terminal `Super` + `Return` (zoom moves to
  `Shift` + `Return`), close window `Super` + `Shift` + `q`, quit dwm
  `Super` + `Shift` + `Escape`, layout toggle `Super` + `Ctrl` + `space`,
  scratchpad `Super` + `s` / `Shift` + `s`, lock `Super` + `Shift` + `l`,
  wallpaper picker `Super` + `Shift` + `w` (random is now `Super` + `w`), theme
  menu `Super` + `Shift` + `t`. New: `Super` + `p` drags a region to the
  clipboard, and `Super` + `Alt` + `p` copies the whole screen to the clipboard
  and saves it as a file. An existing install gets the dwm half on its next
  `dots update`, followed by a logout.

- **Every keybinding is on Super.** dwm's `MODKEY` is now `Mod4Mask`, so the
  window-management keys moved from Alt to Super (`Super` + `p`, `Super` +
  `1`–`9`, `Super` + `h`/`l`, …). Four sxhkd keys moved out of dwm's way:
  firefox `Super` + `Shift` + `b`, lock `Super` + `Escape`, monitor menu
  `Super` + `Shift` + `d`, emoji `Super` + `;`. Alt now reaches applications —
  tmux's `Alt` + `h`/`j`/`k`/`l`, `Alt` + `1`–`9` and `Alt` + `Tab` were
  swallowed by dwm until now. `tests/key-collisions.sh` fails the build when
  dwm and sxhkd grab the same chord.
- Each suckless build now regenerates a `config.h` / `blocks.h` you never
  edited when its `*.def.h` has changed (the old copy is kept as
  `<name>.pre-<timestamp>`); an edited one is kept and the build prints the
  `diff` to merge by. Until now only the 0.1.0 → 0.2.0 migration did this, so
  any later `config.def.h` change — this one included — never reached an
  existing install.

### Fixed

- **Re-running the installer no longer claims to reinstall everything.** It
  printed `installed:` for every package already on the system, and a dry
  run said both "would install" and "installed" for each. Packages that are
  already there are now skipped without calling dnf, which also makes a
  re-run noticeably faster. Each list reports what it actually installed,
  plus one "N already installed" line. Packages are now recognised by what
  they provide, too: on a machine that already had Thunar, the installer
  claimed it as its own, and `dots uninstall` would have removed it. An
  install made before 0.3.0 may still carry that claim. If Thunar was on
  your machine before you installed dots, delete the line that reads
  `PACKAGE` then `thunar` from `~/.local/state/dots/manifest`.
- **`dots doctor` no longer fails `ffmpeg-free` after the RPM Fusion swap.**
  The installer replaces it with RPM Fusion's `ffmpeg`, which conflicts with
  it, so it is never installed again. Doctor now reports it as replaced
  instead of missing, as the installer already did.
- **`dots doctor` says when the GPU is virtual.** Its drivers section used to
  stay silent about a VM's emulated GPU. It now confirms no driver is needed,
  and an unrecognised GPU vendor shows as skipped.
- **`dots update` finishes an install you stopped partway.** It used to read
  the commit each install stage records as it *starts*, so after a Ctrl-C in
  the package stage it said "already up to date" and installed nothing.
  `install-fedora.sh` now records a separate stamp only when a full run
  reaches its end, and `dots update` reads that. A lone `--only-<stage>` run
  does not count as finished either.

- **An update no longer resets your colours to `dark`.** Re-running the
  restore stage with a display (`dots update` from a terminal in your session)
  applied the `dark` theme every time, discarding colours taken from your
  wallpaper or a static theme you had switched to. It now re-applies the
  theme you last chose.

- **The wallpaper download shows progress.** The 400 MB clone printed one
  line and then nothing for a minute or more, which looked like a hang. git's
  progress now goes to the terminal, never into `install.log`.

- `dots update` said "already up to date" whenever its own pull brought
  nothing in, even when the install was from an older commit — which is
  every 0.1.0 install, since those get `update.sh` from a `git pull` done by
  hand. It now compares the commit the manifest says was installed with the
  checkout and re-runs the installer when they differ; `--dry-run` says so.

## [0.2.0] - 2026-10-12

### Added

- `dots update`: pulls the repo (fast-forward only) and re-runs the
  installer, which migrates, installs newly declared packages, rebuilds and
  prints any lines your own `autostart.sh`/`.xinitrc` still need. It refuses
  a dirty tree, a detached HEAD, a missing upstream or a diverged branch
  without touching anything; `--dry-run` lists what would come in.
- The first real migration, 0.1.0 → 0.2.0. It refreshes the suckless
  headers an old build generated (`config.h`, dwmblocks' `blocks.h`), so an
  existing install picks up the new keys, window rules and the DND block. A
  header you edited is kept, and the migration names the upstream changes
  to merge into it. Nothing is deleted: a refreshed header is renamed
  `*.pre-0.2.0`.
- A default wallpaper. A static theme apply renders a gradient from the
  theme's own colours, so a fresh install is no longer a black screen. A
  wallpaper you set yourself is never replaced, and no image is committed
  to the repo.
- Unfocused windows are slightly dimmed by picom. Shadows, rounded corners
  and blur stay off.
- The wallpaper is re-painted after every display change: an autorandr
  `postswitch` hook (at login, on hotplug, and on a profile load) and
  `dwm-display` (Super+d). Before, switching to a saved 1920x1080 layout at
  login left the wallpaper covering only the old 1280x800 corner.
- Inside a VM, `spice-vdagent` (new, in `extra.lst`) resizes the screen to
  the viewer window and shares the clipboard. It never starts on real
  hardware.
- The bluetooth tray icon (`blueman-applet`) starts at login when a
  bluetooth adapter exists. blueman was already installed, but its autostart
  entry is never read in a dwm session.
- A pop-up with a progress bar when the volume, mic or brightness keys are
  pressed (`dwm-osd`, a dunst notification that replaces itself). No new
  packages.
- A `NET` block in the bar: Wi-Fi name and signal, `eth` for a wired link,
  or `off`. Left-click opens `nmtui`. An existing install needs
  `rm suckless/dwmblocks/blocks.h` before rebuilding, because the generated
  `blocks.h` is never overwritten.
- `Super` + `/` opens a searchable list of every keybinding (`dwm-keys`),
  read from `KEYBINDINGS.md`. A new test fails the build when a key in
  `sxhkdrc` has no row there.
- GTK2 apps follow the wallpaper colours, most importantly the password
  prompt (`lxpolkit`), which used to be GTK2's light default. A new template
  writes `~/.gtkrc-2.0`. Fedora 44 no longer packages a dark GTK2 theme, so
  this is a complete set of colours rather than tweaks. A `~/.gtkrc-2.0` of
  your own is never replaced; delete it to use the generated one.
- The GTK desktop portal (`xdg-desktop-portal-gtk`, with `dconf` and
  `dbus-daemon`, in `extra.lst`) and a `portals.conf` that selects it. The
  installer also sets the 'prefer dark' colour scheme, so libadwaita apps,
  Firefox, Chromium and Electron apps use dark mode. It is set only if
  nothing had set it before, and `dots uninstall` resets it unless you
  changed it since.
- Flatpak integration. `flatpak` (in `extra.lst`), the Flathub remote added
  to your user installation, and four read-only global overrides
  (`~/.local/share/icons`, `xdg-config/gtk-3.0`, `xdg-config/fontconfig`,
  `xdg-data/themes`).
  Flatpak apps get the dots cursor and icons and the wallpaper accent
  colours of GTK3 apps; dark mode reaches them through the portal above.
  Settings you already had are left alone, and `dots uninstall` reverts
  only what the installer added: the remote stays while an installed app
  still comes from it. `GTK_THEME` is deliberately not set, because it
  breaks the layout of GTK4/libadwaita apps. `dots doctor` checks the
  overrides and the remote.
- Flatpak app launchers are on every zsh's `PATH`: the user and system
  `flatpak/exports/bin` directories, after everything else, listed by app ID
  (`org.xfce.mousepad`). dmenu (`Mod` + `p`) lists them when the session
  itself was started through your login zsh, the same condition that puts
  `~/.config/dwm/bin` on dwm's `PATH`. Log out and back in to pick it up.
- `dots doctor`: a read-only health report covering:
  - the install: manifest, links, login shell, the login service;
  - every package list, with each missing desktop package's consequence;
  - the X session daemons, the picom backend and the theme;
  - audio, network, bluetooth and the dark-mode setting.

  Each problem names the command that fixes it. `--tsv` prints the same
  checks for scripts. It exits 1 when something the install promises is
  broken.
- `Super` + `.` opens an emoji picker (`dwm-emoji`): every emoji from
  Unicode's data with its name, copied to the clipboard. New package:
  `unicode-emoji`.
- `Super` + `r` starts and stops a screen recording (`dwm-record`): full
  screen or a region, VP9/WebM to `~/Videos/recordings`, no audio. New
  package: `ffmpeg-free`.
- A night light (`dwm-nightlight`, `Super` + `n` toggles): the screen warms
  to 4000 K from dusk to dawn on fixed times. While it runs the brightness
  keys go through it, so the two no longer undo each other. New package:
  `gammastep`.

- `CHANGELOG.md` and `CONTRIBUTING.md`.
- Tests for the seven untested `config/dwm/bin/` scripts (brightness, lock,
  screenshot, powermenu, clipmenu, theme, wallpaper). All nine now have one.
- `tests/install-uninstall-symmetry.sh`: restore then uninstall must return a
  sandboxed home to exactly what it was.
- Dependabot for GitHub Actions and pre-commit hook versions. A bot bump of a
  linter stays red until CI's copy of that pin moves with it.

- `Super` + `` ` `` (grave) toggles a drop-down terminal at the top of the
  screen, starting it the first time; while hidden it is a scratchpad like
  any other (`Mod` + `-` cycles it).
- The status bar answers clicks the way the keys do: scrolling or clicking
  VOL, MIC and GAMMA shows the same pop-up; scrolling GAMMA changes it and a
  left-click toggles night light; CPU, MEM and TEMP open htop; a right-click
  on UPD runs `sudo dnf upgrade --refresh` in a terminal and refreshes the
  count when it finishes. Every terminal a click opens floats.
- Do not disturb: `Super` + `Shift` + `n` pauses notifications and a `DND`
  block appears in the bar (click it to resume); `Super` + `Ctrl` + `n`
  re-shows the last one. `dots doctor` warns while it is left on. An
  existing install needs `rm suckless/dwmblocks/blocks.h` before rebuilding.
- The network tray icon (`nm-applet`) starts at login while NetworkManager
  runs, and `xdg-user-dirs-update` runs at every login. Screenshots and
  recordings now go into your pictures and videos folders, as named by
  `xdg-user-dir` (localised or moved ones included). An existing
  `autostart.sh` gets the lines to paste from `install-suckless.sh`.
- `NetworkManager-tui` (in `desktop.lst`): the NET block's left-click needs
  its `nmtui`, which plain NetworkManager does not include.

### Changed

- Wallpapers are read from `wallpapers/` in your pictures folder, as
  `xdg-user-dir` names it (else `~/Pictures`), like screenshots and
  recordings. That folder is created on first use with the theme's
  generated wallpaper in it, so `Super` + `w` always has something to offer.
- When an existing `~/.xinitrc` already has the session-end step,
  `install-suckless.sh` now prints only the lines it lacks instead of the
  whole block.
- `dots doctor` names the one reason a daemon is not needed here (not a VM,
  no bluetooth adapter, NetworkManager not running) instead of all three.
- pavucontrol, gpick, File Roller and nm-connection-editor open floating.
  The stock dwm rule that meant to send Firefox to tag 9 is gone; it never
  matched Firefox's real window class.
- `tests/lint.sh` lints every tracked shell script at any depth.
  `scripts/theme/` and `scripts/migrations/` had never been linted.
- `tests/dwm-runtime.sh` was split under the 250-line cap, into
  `tests/lib/`.
- The markdownlint pre-commit hook reads `.markdownlintignore` rather than
  keeping a second copy of the same list.

### Fixed

- A dwm restart (every wallpaper change) reset each tag's layout, master
  size, master count and bar to the defaults, and `Mod` + `Tab` forgot the
  previous tag. All of it now survives.
- The wallpaper keys did nothing visible on a fresh install with no
  wallpaper folder (sxhkd discards error output). Every failure is now a
  notification.
- Every wallpaper change or theme switch restarts dwm, and each restart
  moved every window onto one tag, brought hidden scratchpads back and
  re-tiled floating windows. Tags, the view, scratchpads, floating size and
  focus now survive a restart.
- Logging out from the power menu took 20-25 seconds on an idle desktop,
  and a wallpaper-change restart could lag by several: dwm noticed the
  signal only at its next X event. It now acts at once.
- The screen-lock daemon (`xss-lock`) crashed with a core dump at every
  logout. The session's exit step now stops it while X is still up; an
  existing `~/.xinitrc` gets one line to paste.
- Left-clicking the NET block did nothing on a fresh install, because
  `nmtui` was never installed. It is now, and the click falls back to
  nm-connection-editor, then to a notification, instead of doing nothing.
- The UPD block's update list showed dnf5's `Upgrades` header as if it were
  a package.
- `dots doctor` reported a login-time step missing from `autostart.sh`
  (`autorandr`, `xdg-user-dirs-update`) as "runs once" instead of warning.
- Logging out and quickly back in no longer leaves the bar empty (`dwm-6.8`)
  and night light off. The previous session's `dwmblocks` and night-light
  daemon outlived X for a while, so the new session found them, started
  neither, and they died moments later. The generated `~/.xinitrc` now stops
  both when the session ends; an existing one gets the updated block to paste.
- The mouse cursor no longer changes shape between GTK apps such as Firefox
  and the rest of the desktop. The theme's cursor reached GTK only, so the
  wallpaper, the dwm bar, st and alacritty drew the X default. It is now also
  set as the XDG default cursor theme and as `Xcursor.theme`/`Xcursor.size` X
  resources, and a theme switch updates all of them. An existing `~/.xinitrc`
  gets one paste line for the size; `dots doctor` checks the two agree.
- Logging out no longer floods the login screen with
  `xsel: Can't open display` errors. `clipmenud` outlived X and looped on
  failing clipboard calls. The generated `~/.xinitrc` now stops it when the
  session ends. An existing `~/.xinitrc` is never rewritten: the installer
  prints the block to paste in, and `docs/THEMING.md` carries the same block.
- CI's `build-suckless` job had failed on both Fedora images since
  2026-09-08 although every check in `tests/dwm-runtime.sh` passed: its
  cleanup called `pkill`, which the CI container lacks, and that "command not
  found" became the exit status. The job now installs `procps-ng`, and the
  cleanup can no longer change the result. The test's `SIGHUP` reload check
  never passed either, because dwm acts on the signal only at its next X
  event and the test sent none. It now sends one, and the check is a hard
  failure instead of a warning.
- dmenu (`Mod` + `p`) never listed commands from a directory added to `PATH`
  after its cache was built, until something in that directory changed. That
  is how the Flatpak launchers stayed hidden. `dmenu_path` now also rebuilds
  when `PATH` itself changed. It reaches an existing install with the next
  `scripts/install-suckless.sh`; until then, `rm ~/.cache/dmenu_run` has the
  same effect.
- Notifications were drawn on top of the status bar. dunst now places them
  below it (`offset = (12, 36)`). Existing installs pick this up on the next
  wallpaper or theme change.
- No desktop portal worked in a dwm session, so GTK4/libadwaita apps stayed
  light and apps got no portal file chooser. `xdg-desktop-portal` only
  starts once `graphical-session.target` is active, and startx/ly + dwm never
  activated it. `~/.xinitrc` now starts a new `dots-session.target`, which
  does. A `~/.xinitrc` you already had is never edited; the installer and
  `docs/THEMING.md` (Desktop portal) give the lines to add. Log out and back
  in afterwards. `dots doctor` now asks the portal whether it answers, rather
  than trusting the stored dconf preference.
- GTK3 apps (Thunar, and Flatpak GTK3 apps) were light, not dark. Every theme
  names `Adwaita-dark`, which GTK4 has built in but GTK 3.24 does not. On
  Fedora it came from `gnome-themes-extra`, which Fedora 44 retired, so GTK3
  fell back to light Adwaita and ignored the dark preference too. The
  installer now ships that package's one-line `Adwaita-dark` theme for GTK3
  (`~/.local/share/themes/Adwaita-dark`; one you already have is left alone),
  and Flatpak apps get a read-only view of `~/.local/share/themes`. Re-run
  `scripts/install-fedora.sh --only-restore`, then restart GTK3 apps.
  `dots doctor` now warns when the GTK3 theme name resolves to nothing.
- The login shell was recorded as `/usr/sbin/zsh` when the installer ran
  with sbin first on `PATH` (since Fedora 42 sbin is a symlink to bin). A
  later run under a different `PATH` then changed the shell again and
  recorded zsh as the previous one, so `dots uninstall` would have "restored"
  zsh. The path is now resolved first, and an install that already has
  `/usr/sbin/zsh` is corrected on its next services run.
- `dots wallpaper` wrote `~/.fehbg` with bash-only quoting, which a strict
  `/bin/sh` cannot run when the image path contains a tab or other control
  character. It now uses POSIX quoting.
- Uninstall now restores theme configs you had before installing (`dunstrc`,
  `picom.conf`, GTK files). Before, it left the theming engine's version in
  place and your original in `~/.dotfiles-backup/`. Installs made before this
  fix are reported rather than guessed at.
- Uninstall no longer leaves behind a `mimeinfo.cache` the installer created.
- tmux's resurrect directory and the command palette's resurrect entries now
  honour `$XDG_STATE_HOME` / `$XDG_DATA_HOME` instead of hardcoding
  `~/.local`.
- The documentation no longer claims the vendored suckless `.diff` files are
  applied at build time. The sources ship pre-patched; the diffs are a record.
- **Found by the first real install** (Fedora 44 Server VM):
  - The screen no longer freezes after login on a GPU without 3D
    acceleration, which includes most VMs. picom's glx backend stopped
    repainting there. `autostart.sh` now checks the GL renderer with
    `glxinfo` (new package `glx-utils`) and falls back to xrender.
  - A headless install now comes up themed. The installer cannot theme a
    desktop that is not running yet, and nothing used to do it at login;
    `~/.xinitrc` now applies the dark theme on the first login and restores
    it on every later one.
  - The login shell is now actually set to zsh. `chsh` needs your password
    on a terminal and failed silently from the script; the installer and
    uninstaller now use `sudo usermod -s`.
  - An existing `autostart.sh` or `~/.xinitrc` is still never edited. The
    installer prints the lines to add instead.

## [0.1.0] - 2026-09-03

The first version. It was never tagged, and everything up to this point
shipped as 0.1.0.

### Added

- **One Fedora installer**, `scripts/install-fedora.sh`, for a fresh Fedora
  Server or Workstation box. It installs Xorg itself. It runs four idempotent
  stages (pre, packages, restore, services), each runnable on its own, with
  `--dry-run` threaded through all of them.
- **A patched suckless desktop**: dwm (13 patches, including pertag, systray,
  status2d, restartsig, xresources and dynamic scratchpads), st, dmenu (8
  patches), dwmblocks (10 blocks plus the tray) and slock. All are vendored in
  `suckless/`, each with a `PATCHES.md` record. `ly` is the display manager.
- **A wallpaper-driven theming engine**: ImageMagick colour extraction, `.dcol`
  templates, and an ordered live reload of dwm, st, dmenu, slock, dwmblocks,
  dunst, picom, GTK, alacritty, starship, fastfetch and vim. There are four
  static themes (dark, gruvbox, nord, tokyo-night), and a theme switch also
  applies its GTK, icon, cursor and font identity.
- **The desktop roster**: alacritty (st as the no-GPU fallback), sxhkd for
  media, brightness, screenshot, lock and theme keys, maim+slop screenshots,
  xss-lock+slock, Thunar with archive and thumbnail support, picom, dunst,
  starship, fastfetch, xsettingsd, udiskie, autorandr, lxpolkit, a dmenu
  colour picker and a display menu, and a vendored Bibata cursor theme.
- **`dots`**, one command on `$PATH`: `dots theme`, `dots wallpaper`,
  `dots version` and `dots uninstall`, with zsh completion.
- **A four-tier package model** in `packages/*.lst` (core, build, desktop,
  extra). A failed desktop package is repeated in a red closing summary that
  says what it costs.
- **Manifest-driven uninstall and versioning**: `scripts/uninstall.sh`
  reverses what the installer recorded, restoring backups. `VERSION`,
  `scripts/version.sh` and the `scripts/migrations/` framework track installs.
- **zsh and tmux configuration** (zinit, TPM, resurrect/continuum, a command
  palette), all following XDG.
- **CI**: shellcheck, shfmt and markdownlint (all version-pinned), the test
  suite, the suckless build with dwm run under Xvfb, an installer dry run,
  and a full installer run in Fedora containers (latest plus oldest
  supported).

### Fixed

These were caught before 0.1.0 was ever tagged. They are listed because each
one affected real installs up to that point:

- No display manager was ever enabled: Fedora ships a templated
  `ly@.service`, so the installer now enables `ly@tty2.service`.
- The installer aborted under `set -u` when `$USER` was unset.
- `polkit-gnome` was retired from Fedora, which left a fresh install with no
  PolicyKit agent. It was replaced by `lxpolkit`.
- The CI matrix was pinned to an end-of-life Fedora release.
