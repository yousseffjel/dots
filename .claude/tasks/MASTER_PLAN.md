# MASTER_PLAN — dots

Last Updated: 2026-10-20

Strategic roadmap. One task per slot; multiple `## Active` entries allowed
when slots run concurrently.

---

## Active

(none)

---

## Queue

- ~~**Scope J — live-ISO install (Epic, opened 2026-10-15).**~~ ✅ **Done
  2026-10-19** — see Recently Closed.

- ~~**Live install: an interrupt does not stop the inner `install-void.sh`.**~~
  ✅ **Done 2026-10-19** — see Recently Closed.

- ~~**Release 0.5.0**~~ ✅ **Done 2026-10-19** — see Recently Closed.

- ~~**Void packages `gnome-themes-extra` (+ `-gtk`).**~~ ✅ **Done 2026-10-19** — see Recently Closed.

- ~~**TESTING.md still has Fedora-era sections**~~ ✅ **Done 2026-10-19** — see Recently Closed.

- ~~**A ly pin bump never reaches an existing install.**~~ ✅ **Done 2026-10-19** — see Recently Closed.

- ~~**`polkit-gnome` is retired — a fresh install has no PolicyKit agent.**~~
  ✅ **Done 2026-08-13** — see Recently Closed. Two things this entry got wrong,
  both corrected there: it was absent from **f43 as well as f44**, and the fix
  was *not* a libexec path update — `lxpolkit` is on `PATH`, so the fallback was
  deleted rather than re-pointed.
- ~~**CLAUDE.md rule 5 describes a build step that does not exist.**~~
  ✅ **Done 2026-09-28** (`0bf4065`) — rule 5 now says the diffs are a record;
  `patch` **kept** in build.lst by user decision, comment corrected.
- ~~**`@resurrect-dir` hardcodes `$HOME/.local/state`**~~ ✅ **Done 2026-09-28**
  — plus the same bug in `tmux-palette`, now guarded tree-wide by
  `tests/tmux-xdg-paths.sh`.
- ~~**Watch the first CI run after 2026-08-10.**~~ ✅ **Closed 2026-10-12** —
  lint and build-suckless have been green on every run since (e.g. `68cfb53`).
  Original entry: The `lint` and `build-suckless`
  jobs were rewired to invoke `tests/lint.sh --strict` and `tests/build.sh`
  without CI ever executing once. Two things are unproven: that
  `npm install -g` works without sudo on a GitHub-hosted runner, and that
  shfmt on `$GITHUB_PATH` is visible to `lint.sh`'s `command -v`. Both fail
  loudly rather than silently (`--strict` is what guarantees that), but they
  have not been observed.
- **Run `install-void.sh` end-to-end on real hardware.** Never done on bare
  metal. Covered so far: the install-container CI job (a Void container),
  the Void VM (2026-10-15, QXL, ly; `dots doctor` all passed) and the
  live-ISO VM matrix {UEFI, BIOS} x {plain, LUKS} (2026-10-19). Still
  open: **bare metal** (ly login on real hardware), a **real GPU** (the glx
  branch of `dwm-picom` is tested only against fake glxinfo output), and a
  **real laptop** (scope-h's backlight, BAT, touchpad and power profiles
  are fixture-tested only). Needs the user's hardware.
  (Fedora history: a Fedora 44 Server VM run on 2026-10-05 found three bugs,
  fixed in `first-boot-fixes`; the entry named `install-fedora.sh` until the
  port. Rewritten 2026-10-19.)

### Framework parity with HyDE (opened 2026-08-12 by a fresh HyDE diff)

Source: comparison against the local HyDE clone at `8fa0073e` (2026-08-01),
inspected directly rather than from `ROADMAP.md`. These are the **structural**
gaps; the desktop-feature gaps from the same pass (tray applets, bluetooth
service, volume/brightness OSD, battery, network block, screen recorder,
`.gtkrc-2.0`, blue-light filter, emoji picker, keybind hint) were reviewed at
the same time and **not** queued — raise them separately if wanted.

- ~~**A single user-facing command on `$PATH`.**~~ ✅ **Done 2026-08-13** — see
  Recently Closed. Landed as a real dispatcher, not symlinked entry points:
  one name in the contested `~/.local/bin` namespace instead of four.
- ~~**Font and cursor assets that Fedora does not package.**~~ ✅ **Done
  2026-08-13** — see Recently Closed. **This entry was wrong twice.** Fonts were
  already fully packaged, so only cursors were missing; and HyDE's
  `restore_fnt.sh` does not download from GitHub releases at all — it extracts
  archives already in the clone, which is the approach taken.
- ~~**`CHANGELOG.md` + `CONTRIBUTING.md`.**~~ ✅ **Done 2026-09-28** — release
  boundary: everything to date is the untagged 0.1.0; `[Unreleased]` from now.
  `tests/changelog-version.sh` guards VERSION vs the newest heading.
- ~~**Dependency automation for the pins.**~~ ✅ **Done 2026-09-28** —
  Dependabot (actions + pre-commit) + `tests/linter-pins.sh` as its lockstep
  gate; fedora image and suckless sources are a documented manual sweep.

---

## Recently Closed

- 2026-10-21 — **monitor-capture** (`0865a45`, ff; log
  `2026-10-21-monitor-capture.md`). Screenshot and recording `monitor` mode:
  the screen under the pointer.

- 2026-10-21 — **display-presets** (`2b0ad18`, ff; log
  `2026-10-21-display-presets.md`). Super+Shift+d keeps active screens'
  modes and the real primary; saves the layout as an autorandr profile.

- 2026-10-21 — **clipmenud-match** (`db56814`, ff; log
  `2026-10-21-clipmenud-match.md`). clipmenud stopped at logout by -f (it
  runs as "bash" on Void); old .xinitrc files told the line to replace.

- 2026-10-21 — **palette-missing-keys** (`942ee41`, ff; log
  `2026-10-21-palette-missing-keys.md`). A palette missing a template key is
  refused before anything is written; it used to end the X session.

- 2026-10-21 — **update-arg-check** (`9e05019`, ff; log
  `2026-10-21-update-arg-check.md`). `dots update` refuses a flag the
  installer does not take before it fetches, instead of after the pull.

- 2026-10-21 — **stale-port-text** (`23fa145`, ff; log
  `2026-10-21-stale-port-text.md`). Printed help/messages no longer name
  dnf/rpm/ffmpeg-free or "PORT IN PROGRESS"; tests/runtime-text-void.sh guards it.

- 2026-10-21 — **theme-lock-scope** (`c5673a3`, ff; log
  `2026-10-21-theme-lock-scope.md`). Host edge-case pass: the theme lock was
  taken before arguments were read, so `dots theme --list` (the Super+Shift+t
  menu) waited behind any change, and the `--select` picker held the lock
  while open. Only a change locks now. wallpaper.sh split (250 -> 220).
  VM-verified 2026-10-21: `--list`/`--help` return at once with the lock held.

- 2026-10-21 — **uninstall-dryrun-preview** (`84ec6c7`, ff; log
  `2026-10-21-uninstall-dryrun-preview.md`). Void VM finding: `dots uninstall
  --dry-run` asked each category first, so without a terminal it previewed
  nothing. A dry run now asks nothing. Also fixed: keeping no copy of the
  log made a finished uninstall exit 1. VM-verified 2026-10-21: every
  category previewed, nothing changed.

- 2026-10-20 — **migrate-dryrun-current** (`a12240f`, ff; log
  `2026-10-20-migrate-dryrun-current.md`). Void VM finding:
  `install-void.sh --dry-run` stopped silently (rc=1) at the migrations step
  on any up-to-date install. migrate.sh's trailing `[[ ]] && …` is now an
  if/elif branch; the dry run reaches all four stages and writes nothing.

- 2026-10-20 — **help-render-aligned** (`0626ec1`, ff; log
  `2026-10-20-help-render-aligned.md`). VM edge-case pass: `dots theme --help`
  had a wrapped line four columns off after the name swap, and theme and
  wallpaper help opened blank. tests/dots-dispatch.sh now checks every
  subcommand's help.

- 2026-10-20 — **wallbash-choice-recorded** (`864b2a7`, ff; log
  `2026-10-20-wallbash-choice-recorded.md`). Void VM finding: a wallbash
  choice made after a static theme was lost on the next `dots update`.
  `theme-apply.sh --wallbash` now records it in wall.set. Verified on the VM.

- 2026-10-20 — **xresources-cpp-safe** (`6b1910d`, ff; log
  `2026-10-20-xresources-cpp-safe.md`). xrdb's cpp warned on an apostrophe in
  the xresources template; reworded, and a test bans `'` and `/*` there.

- 2026-10-20 — **theme-change-lock** (`35313cc`, ff; log
  `2026-10-20-theme-change-lock.md`). Void VM finding: concurrent wallpaper
  changes mixed one wallpaper with another's colours. Changes now run one at
  a time under `flock -o`. Verified on the VM. **Watch:** wallpaper.sh is
  at 250 lines; split it before the next addition.

- 2026-10-20 — **complete-stamp-cleared** (`848acac`, ff; log
  `2026-10-20-complete-stamp-cleared.md`). Void VM finding: an interrupted
  re-run of an already-finished commit read as finished to `dots update`. A
  full run now clears the stamp after the pre stage. Verified with a real
  SIGINT on the VM.

- 2026-10-20 — **running-build-stale** (`2e6446a`, ff; log
  `2026-10-20-running-build-stale.md`). Void VM finding: a rebuild under a
  live session left dwm/dwmblocks on the old binary, silently. Both
  installers now end with the in-place restart hint; `dots doctor` warns.
  Verified live on the VM. **Also VM-verified today:** the 0.4.0 → 0.5.0
  upgrade (release-0.5.0), nsxiv as a package (nsxiv-package) and
  dunst-keep-state — their "Not verified" notes below are closed.

- 2026-10-20 — **update-upstream-gone** (`746330a`, ff; log
  `2026-10-20-update-upstream-gone.md`). Void VM finding: `dots update` on a
  branch deleted on the remote (`void`) said "nothing to pull" forever. Now
  `fetch --prune` and a refusal naming the branch, hint `git switch main`.
  5/5 mutants, suite 95 OK, reviewer READY, checked on the VM.

- 2026-10-20 — **suite-host-hermetic** (`324b6d6`, ff; log
  `2026-10-20-suite-host-hermetic.md`). The suite passes on a dev host with
  autorandr or a system Adwaita-dark (sealed PATH in the dwm-display tests,
  XDG_DATA_DIRS sandboxed for doctor); `--help` of install-void.sh and
  symlinks.sh prints the whole header, guarded by tests/help-header.sh.
  6/6 mutants, suite 95 OK on the host, reviewer READY. Records: the
  2026-10-05 logs archived, CURRENT_AUDIT.md rotated (snapshot
  `CURRENT_AUDIT-2026-10-20.md`).

- 2026-10-19 — **ly-rebuild** (`bb86190`, ff; log `2026-10-19-ly-rebuild.md`).
  A raised ly pin rebuilds existing installs: `META ly_build` record (none =
  1.4.1), rename-into-place (a running ly blocks cp), config.ini kept, stale
  paths pruned with their rows, ly never restarted. 10/10 mutants, suite 94
  OK, reviewer READY. **Not verified:** on the VM (no newer ly to bump to).

- 2026-10-19 — **testing-void** (`863380a`, ff; log
  `2026-10-19-testing-void.md`). User decision: keep the GTK3 shim and the
  gtk2 template (Void's gnome-themes-extra GTK3 file is byte-identical; its
  GTK2 theme has fixed colours). TESTING.md reconciled with Void. Docs only.

- 2026-10-19 — **release-0.5.0** (`868a481`, ff; log
  `2026-10-19-release-0.5.0.md`; local tag `v0.5.0`, not pushed). 0.5.0 cut;
  `scripts/migrations/0.4.0-to-0.5.0.sh` removes the vendored nsxiv build
  its manifest row records, the rows, and unedited `suckless/nsxiv/`
  leftovers. `tests/migration-0.5.0.sh`, 7/7 mutants, suite 94 OK, reviewer
  READY. **Not verified:** a real 0.4.0 → 0.5.0 upgrade on the VM.

- 2026-10-19 — **claude-md-void** (`45e575d`, ff; log
  `2026-10-19-claude-md-void.md`). CLAUDE.md no longer states Fedora facts
  as current: verification, the installer, xcolor, laptop power, the
  pending list, the theming reasons (plus Void's gnome-themes-extra facts),
  dwm-titus and rule 10. History kept and marked. Two follow-ups queued.

- 2026-10-19 — **nsxiv-package** (`30e9120`, ff; log
  `2026-10-19-nsxiv-package.md`). nsxiv is Void's package (`extra.lst`), and
  `suckless/nsxiv` is deleted, with its build deps and install targets. The
  colour picker stays a script though Void packages xcolor. Both decisions
  were the user's (2026-10-19), and they close scope I's last open question.
  2/2 mutants caught. **Not verified:** the package on the VM.

- 2026-10-19 — **live-interrupt** (`d4bc7cf`, ff; log
  `2026-10-19-live-interrupt.md`). Ctrl-C stops an install. Direct run:
  `stop_on_interrupt` (global_fn.sh) in install-void.sh and every stage, since
  xbps exits 0 on a SIGINT mid-verification and bash carried on. Live ISO:
  `live_dots_cleanup` on EXIT stops everything rooted in the target, then
  removes the NOPASSWD rule (`su -c` had orphaned the stage). Proved with a
  real Ctrl-C from the live ISO on a VM (exit 130, nothing left in /mnt, the
  rule gone, and the re-run converged). 5/5 mutants caught.

- 2026-10-19 — **Scope J — live-ISO install** (Epic, 5 slots, all ff:
  `0bec1f5` J-1 live-core, `86c6df9` J-2 live-dots, `6a9cb4f` J-3 live-disk,
  `17898dd` J-4 live-luks, `f12da26` J-5 live-docs). `scripts/install-live.sh`
  takes a machine from the Void live ISO to the ly login: disk pick + erase,
  GPT for UEFI or BIOS, optional LUKS2 root, zram + swapfile, base system
  with `linux` + `linux-lts`, GRUB, then dots as the user. Guide:
  `docs/LIVE-INSTALL.md`. Full {UEFI, BIOS} × {plain, LUKS} matrix passed
  from the ISO; J-5 also fixed ly's first-boot login. Two follow-ups queued.
  **Not verified:** bare metal, Secure Boot, NVMe (tests only).

- 2026-10-15 — **Scope I — port to Void Linux glibc** (Epic, `783a28a`..`43e76ff`,
  13 commits, ff into main). DECISION REVERSAL of "Fedora only": main is now
  Void-only. I-1..I-10 done: xbps engine, nonfree repo, runit + elogind, ly
  built from source, session via dbus-run-session + PipeWire, VM detection,
  CI in `void-glibc-full`, and a real Void VM run (`dots doctor` all passed;
  found the VOL-block race, fixed by `dwm-audiowatch`). Fedora-specific Queue
  entries are superseded wherever the port removed their code.
  **Not verified:** bare metal, suspend/resume, a laptop.

- 2026-10-15 — **ad-hoc: `dunst-keep-state`** (`c51a26e`, ff). Found on the VM
  right after notify-center: a theme apply restarted dunst (empty history,
  focus mode off). Now `dunstctl reload` with the pause level restored, and
  OSD pop-ups kept out of history. **Not verified:** on the VM.

- 2026-10-15 — **ad-hoc: `notify-center`** (`34facae`, ff) + `xdg-utils-desktop`
  (`6460356`). Notification centre (dmenu, top-right via a local xyw patch:
  open / delete / clear all) and an always-visible bell/FOCUS button.
  **Open item:** the 0.4.0 → 0.5.0 migration must refresh an unedited
  `suckless/dwmblocks/blocks.h`. **Not verified:** VM / live desktop. (Open item closed
  2026-10-19: not needed, `refresh_generated_headers` already does it.)

- 2026-10-15 — **ad-hoc: `ci-timeout`** (`3594d4f`, merge `a31e68a`).
  install-container `timeout-minutes` 90 → 20: batched legs take 2:38 / 3:25
  (run a1f8054), per-package CI legs ~8 min. Comments and CLAUDE.md carry the
  measured figures. **Not verified:** the next install-container run on push.

- 2026-10-14 — **ad-hoc: `dnf-speed`** (`906e5e0` + `81bcf7e`, merge `fe037e8`).
  A fresh F44 VM install sat an hour on a 3 KiB/s mirror after 37 min of
  one-dnf-per-package. Now: a persistent dnf5 drop-in (fastestmirror, 10
  parallel, minrate 20k; SYSFILE row, shared `sysfile_install` with the
  touchpad), one forced `makecache --refresh` up front, one transaction per
  tier with per-package fallback, dead group step removed. VM: drop-in read
  by dnf, batch installed 2 packages, doctor all passed. Fresh VM
  (192.168.122.172) full install: 4 min 20 s, 3 transactions. CI installer
  step 8:14 → 2:19 (f43). Staircase fix verified on the VM 2026-10-15
  (progress aligned at the 4-space indent). **Not verified:** dnf5 falling
  over to the next mirror after a minrate abort.

- 2026-10-14 — **ad-hoc: release 0.3.0 + follow-ups — 5 slots merged**
  (`c421621`).
  - [x] `installer-honest-status` (`f923f78`): no false "installed:", no dnf
        for installed packages; `--whatprovides` (thunar → Thunar).
  - [x] `release-0.3.0` (`20255ad`): VERSION 0.3.0, no-op migration, release
        docs fixed (a migration is REQUIRED per release). Tagged v0.3.0 by
        the user; VM upgraded 0.2.0 → 0.3.0.
  - [x] `installer-honest-status-2` (`7f9b37e`): COPR step + repos via
        `drivers_pkg`; no re-enable, no reinstall.
  - [x] `vm-picom` (`6caa7d2`): `vm` chassis; `dwm-picom` (VM → xrender,
        glx only on bare-metal hardware 3D); doctor compares backends.
  - [x] `server-target` (`4dfaff2`): Fedora Server is the one target; GDM
        note in pre-flight.
  ✅ VM 2026-10-14: `dots update` 11 s, doctor all passed.
- 2026-10-13 — **Epic: scope-h — laptop support — ALL 5 SLOTS MERGED**
  (`e1ecabc`). Scope file `.claude/tasks/scope-h-laptop-support.md`.
  **DECISION REVERSAL** of scope-b locked decisions 9 and 12: dots targets
  desktops AND laptops; a desktop behaves exactly as before.
  - [x] 1+2 — `laptop-detect` (`befcde1`): `drivers_chassis`, gated
        `packages/laptop.lst`, backlight via brightnessctl (block `BL`/`GAMMA`).
        Merged into one slot: tests/pkglist.sh forbids an empty list.
  - [x] 3 — `laptop-battery` (`6b6ee3f`): `BAT` block, 15 %/5 % alerts, no daemon.
  - [x] 4 — `laptop-touchpad` (`d29659c`): Xorg InputClass snippet, new
        SYSFILE manifest rows + `uninstall-sysfiles.sh`. Real Xorg parsed it.
  - [x] 5 — `laptop-power` (`a7f7a6c`): tuned-ppd + `dwm-power` (gdbus),
        Super+Shift+p; `uninstall_services` tolerates units removed with
        their package.
  ✅ VM 2026-10-13: `dots update` + doctor clean; reads as `unknown`, nothing
  laptop-only installed, BAT block present but empty. Open: verify on a real
  Fedora laptop (none available — fixtures only).
- 2026-10-13 — **ad-hoc: hardware drivers — both slots merged** (`10bbad3`).
  - [x] `hardware-drivers` (`b96785b`): `dots drivers` — GPU VA-API driver,
        kernel-requested firmware, microcode, fwupd; NVIDIA report-only.
  - [x] `doctor-swap-virtual-gpu` (`856d732`): no false ffmpeg-free FAIL after
        the swap; virtual GPU reported; doctor test sandbox sealed.
  ✅ Verified on the VM 2026-10-13 (virtio GPU only). Open: real AMD or NVIDIA
  hardware, and the f43 mesa swap.
- 2026-10-12 — **ad-hoc: Super modkey + ly login theme — both slots merged**
  (`aadcf5f`).
  - [x] `super-modkey` (`d604000`): every binding on Super; build-time refresh
        of unedited stale suckless headers; `tests/key-collisions.sh`.
  - [x] `ly-theme` (`ca5f15f`): `dots login-theme`; install + static switch;
        uninstall restores ly's values.
  - [x] `ignore-header-backups`: `*.h.pre-*` gitignored.
  - [x] `ly-console-colours` (`6c79fdd`): border drawn white on the VT — mapped
        to the hue-nearest console colour.
  ✅ All verified on the VM 2026-10-12: Super keys, ly clock/version, blue border.
- 2026-10-12 — **Epic: scope-g — polish, per-tag restart, release 0.2.0 —
  ALL 3 SLOTS MERGED.** Scope file `.claude/tasks/scope-g-release-0.2.0.md`.
  - [x] 1 — `polish-bundle` (`65e1dcd`)
  - [x] 2 — `pertag-restart` (`2dbfcf5`)
  - [x] 3 — `release-0.2.0` (`695f1d5`): VERSION 0.2.0, `dots update`,
        the first real migration, the first tests of migrate.sh
  Open: tags (v0.1.0 at d997704, v0.2.0). ~~A live `dots update` on the VM~~ —
  ✅ done 2026-10-12, and per-tag restart verified by hand there.
  - [x] follow-up `update-stale-install` (`9c5599d`): `dots update` re-runs the
        installer when the install is older than the checkout. VM upgraded to
        0.2.0 by hand the same day; doctor green.

- 2026-10-12 — **Epic: scope-f — desktop integration pass — ALL 4 SLOTS
  MERGED.** Scope file `.claude/tasks/scope-f-desktop-integration.md`.
  - [x] 1 — `dwm-rules-scratchpad` (`e44d331`): preserveonrestart (every
        wallpaper change used to scatter the desktop), dropterm, float rules
  - [x] 2 — `bar-integration` (`2efa910`): bar clicks match the keys; all
        blocks tested
  - [x] 3 — `session-integration` (`d19069f`): nm-applet, xdg-user-dirs,
        DND block + keys, doctor dunst check
  - [x] 4 — `vm-verify` (`dffc91e`): everything above passed live on the
        Fedora 44 VM, which found four more defects, all fixed:
        wakeonsignal (logout took 20-25 s), xss-lock core dump at logout,
        doctor one-shot ordering, NetworkManager-tui undeclared. Also
        back-filled the CHANGELOG lines no slot had written.
  Still to see live on the VM: those four fixes (after a pull + rebuild),
  `pkexec true` floating, the sudo prompt in the upgrade terminal.

- 2026-10-06 — **Flatpak integration (scope E,
  `scope-e-flatpak-integration.md`)**. Flathub plus four read-only overrides,
  each reverted only while still as written. The VM check found two older
  bugs and both are fixed: GTK3 `Adwaita-dark` was unresolvable on Fedora 44,
  so all GTK3 apps were light (vendored shim; VM-verified dark), and no
  desktop portal could start in a dwm session (`dots-session.target`).
  Flatpak launchers are on PATH for dmenu, and `dmenu_path` now rebuilds its
  cache when PATH changes (`dmenu-path-cache`). **Fully VM-verified:** the
  portal answers (Flatpak Text Editor dark), Mod+p lists Flatpak apps, and
  the Bibata cursor holds over a Flatpak window.
- 2026-10-06 — **GTK2 theme, desktop portal, `dots doctor`** ("what is next"
  items 4 + 5, as the user re-picked them). GTK2 apps are themed from the
  wallpaper via `~/.gtkrc-2.0`. xdg-desktop-portal-gtk + `prefer-dark`
  reverse scope C decision 5. `dots doctor` replaced item 5, which was
  already done (scope D). The portal answering and a real `dots doctor` run
  inside dwm were VM-verified with scope E; still unverified: lxpolkit's
  dialog (`pkexec true`). Scope E (Flatpak, another session's file) is
  now unblocked.
- 2026-10-05 — **desktop features round**: from the HyDE feature-gap list,
  the user picked the ⭐ option for seven rows: bluetooth tray applet,
  volume/brightness pop-up, NET block, keybind cheat sheet (Super+/), emoji
  picker (Super+.), screen recorder (Super+r) and night light (Super+n,
  owning the gamma with the brightness keys). Battery block stays out by the
  desktop decision. Still unverified on the VM: x11grab on the virtio GPU,
  repeated gamma applies on a real X server, the NET block (needs a fresh
  `blocks.h`).
- 2026-10-05 — **first-boot-fixes**: the first real install (Fedora 44 VM)
  found three bugs: picom's glx backend froze the screen (now a glxinfo
  probe), a headless install was never themed (now themed in `~/.xinitrc`),
  and `chsh` failed silently (now `sudo usermod`). Re-tested on the VM.
- 2026-10-05 — **visual-defaults** + **wallpaper-follows-display**: a
  wallpaper generated from the palette, picom inactive dimming, a
  spice-vdagent VM agent, and a wallpaper re-paint after every display
  change. Confirmed on the VM at 1920x1080.

- 2026-09-28 — **the seven untested `config/dwm/bin/` scripts** — all nine
  now have a test. Four new files on a sealed PATH (`tests/lib/sealed-path.sh`).
  17/17 mutations; two survivors on the first pass each exposed a weak
  assertion (fixed, not documented). Closes the 2026-08-12 note "Seven dwm-*
  scripts remain untested".

- 2026-09-28 — **Epic: scope-d — verification harvest from dwm-titus — ALL 4
  SLOTS MERGED.** Scope file `.claude/tasks/scope-d-verification-harvest.md`.
  - [x] A — CI build deps from `packages/build.lst` (2026-09-03)
  - [x] B — `tests/run-tests.sh` + `.claude/config.yml` (2026-09-03)
  - [x] C — `tests/dwm-runtime.sh` under Xvfb (2026-09-03)
  - [x] D — install/uninstall symmetry — `e013c3c`. Found and fixed two real
        uninstall bugs: an unclaimed `mimeinfo.cache`, and pre-existing theme
        configs never restored (THEMEBACKUP rows had no backup path). The
        `.zshenv` line + zinit/TPM clones stay as DOCUMENTED leftovers — user
        chose to honor `docs/UNINSTALL.md` over a reversal (conflict surfaced
        2026-09-28).
  The Epic's thesis held in every slot: each one found something only
  execution could.

- 2026-09-28 — **dependency automation** — `bfb0c81`. `.github/dependabot.yml`
  (github-actions + pre-commit, monthly). `tests/shellcheck-pin.sh` ->
  `tests/linter-pins.sh` covering all three linters, so a bot bump stays red
  until ci.yml's mirror moves. Closes the last HyDE-parity queue item.

- 2026-09-28 — **CHANGELOG.md + CONTRIBUTING.md** — user chose "0.1.0 +
  Unreleased"; 0.1.0 dated at `d997704`, untagged. CONTRIBUTING points at
  CLAUDE.md rule numbers instead of restating them. New
  `tests/changelog-version.sh` (4/4 mutations).

- 2026-09-28 — **tmux XDG paths** — `@resurrect-dir` (queued) and
  `tmux-palette`'s resurrect entries (found by the scan; the 2026-08-10 sweep
  missed it because the lockstep test names two files). New
  `tests/tmux-xdg-paths.sh`: tree-wide static sweep plus a live isolated tmux
  server. 4/4 mutations caught, one only by the live layer.

- 2026-09-28 — **rule 5 made true** — `0bf4065`. The `.diff` files were never
  applied by anything; rule 5, the project map, build.lst's `patch` comment and
  `tests/ci-build-deps.sh` said otherwise. `patch` stays (user's call) with its
  hard-fail cost stated. Reviewer WARN on an overstatement, fixed pre-commit.

- 2026-09-28 — **`tests/dwm-runtime.sh` split under the 250-line cap** —
  `74e1cfe`. Found by the 2026-09-28 scan. It also removed `tests/lint.sh`'s
  `-maxdepth 2`, which meant CI had never linted `scripts/theme/*.sh` or
  `scripts/migrations/*.sh` (all clean). Output-equivalent to the pre-split
  test, and both slot-C mutations are still caught.

- 2026-08-13 — **PolicyKit agent: `polkit-gnome` → `lxpolkit`** — `6ff4a55`,
  `00cd483`. Closes the top queue item; CI was red in two jobs and every fresh
  install since the retirement had no agent at all. **The entry was wrong
  twice:** the package is gone from **f43 as well as f44** (verified with a
  control query, since its packages.fedoraproject.org page still returns 200
  while listing only EPEL 9), and the prescribed "update the absolute libexec
  path" was not the fix — `lxpolkit` sits at `/usr/bin`, so the two-branch
  fallback was deleted and the block moved from `session_autostart_services()`
  to `_daemons()`, which its own header required. All four rule-6 sites moved
  together, 3/3 coupling mutations caught, two stale enumerations deleted rather
  than corrected. **The reviewer BLOCKed on a doc claim this task introduced** —
  a supersession note spliced mid-sentence left prose asserting the code still
  tried two paths. Third consecutive task where that gate caught a claim/reality
  gap. **Supersede by appending a dated paragraph, never by interleaving.**

- 2026-08-13 — **one command on `$PATH`, and a vendored cursor theme** —
  `5ed65b3`, `9c0438d`. Closes two of the four HyDE framework-parity items in
  one slot. `scripts/dots` dispatches to the four user-facing scripts (nothing
  moved; all stay independently runnable) and its `SUBCOMMANDS` table is the
  only declaration of the list — `--help`, the zsh completion and the test all
  read it back. It deliberately breaks rule 3 with `readlink -f`, because a
  symlinked entry point makes `cd "$(dirname …)"` resolve `~/.local/bin`
  instead of the repo. Bibata is vendored under `assets/cursors/` with checksum
  and licence, extracted into `~/.local/share/icons` as a `THEME` row, and its
  name is read out of the archive rather than hardcoded.
  **Both queue entries were wrong about their own scope:** the "font and cursor"
  item was already half-done (fonts were fully packaged), and its stated trust
  concern — downloading at install time — is not what the reference
  implementation does. Suite 13 → 15, **15/15 green on main post-merge**,
  19/19 mutations caught. Three lessons: **a queue entry is a pointer, not a
  brief**; **stage after fixing, not before auditing** (an early `git add`
  had the reviewer BLOCK on a stale index, right about the commit and wrong
  about the tree); and **a function sitting exactly on the 60-line cap is a
  latent hard stop**.

- 2026-08-13 — **the installer runs in CI for the first time** — `c4afeb3`,
  `3e3e6a5`. Closes the parity item "a container harness that runs
  `install-fedora.sh` for real". New `.github/workflows/install-container.yml`
  (its own file, `paths:`-filtered, `timeout-minutes: 90` from a **measured**
  32-minute cold run) executes the installer to completion in `fedora:latest` +
  `fedora:43` and makes **23 assertions**, every one derived from a shipped
  source of truth rather than restated. **8/8 mutations caught; 13/13 test
  scripts executed** (`build.sh` run in the container rather than skipped).
  **It found two bugs on its first run**, both live on real hardware: `$USER`
  unbound under `set -u`, and `systemctl enable ly.service` targeting a unit
  that does not exist — Fedora's `ly` ships a templated `ly@.service`, so **no
  display manager had ever been enabled by this installer on any machine**. Now
  `ly@tty2.service`. Two lessons worth carrying: **verification that inspects
  inputs cannot find a wrong output** — the `ly` bug survived every lint,
  review and package-name check because none of them ever ran the line; and the
  reviewer's BLOCK was on a **claim**, not on code (a comment described a
  `getent` check that was never written), which four audit sweeps missed by
  reading the assertions and the prose separately.

- 2026-08-12 — **theme roster 1 → 4 + `theme.conf` identity wiring** —
  `60134a0`, `fb9f075`. Closes the parity queue item "More than one theme under
  `themes/`". `gruvbox`, `nord`, `tokyo-night`, every `colors.dcol` **generated**
  by `colorgen.sh` from a recorded seed hex and confirmed to regenerate
  byte-identical. The wallpaper question that item asked to settle first was
  settled: **a theme carries no `wallpapers/`** (Type C, per
  `themes/dark/wallpapers/README.md`). Scope grew beyond colours because
  `theme.conf` was report-only — a switch now applies GTK/icon/cursor/font
  identity through the installer's own writers, never clobbering a file the
  manifest does not claim. `tests/theme-identity.sh` (suite 12 → 13), 9/9
  mutations caught. Two lessons: **a test that supplies a default never tests
  it**, and **the stale doc is the sibling you did not create**.

- 2026-08-12 — **CI off the EOL Fedora pin** — `6156aa6`, `6e840d7`. Both
  matrices `fedora:41` -> `fedora:43` (oldest supported), with a comment saying
  the pin must be bumped rather than deleted. The queue entry's own rationale
  was wrong and the audit caught it being copied into the code: an EOL image
  does not vanish, its repos move to archive mirrors and `dnf` breaks while the
  image still pulls. Tag existence verified against Docker Hub before shipping.

- 2026-08-12 — **first tests for `config/dwm/bin/`** — `67d417f`, `9849c6d`.
  Nine scripts, zero tests, until `dwm-colorpicker.sh` (12 assertions) and
  `dwm-display.sh` (20). Suite 10 → 12, both picked up by CI's glob for free.
  **12 of 13 deliberate mutations fail the suite** — that measurement, not the
  assertion count, is what makes them load-bearing. The one survivor is
  documented in the test header rather than papered over. Two lessons:
  ImageMagick is deliberately NOT faked (faking the thing under test leaves the
  file asserting against its own fixture generator), so it skips **loudly**
  where CI cannot provide it; and **mutation testing only covers the mutations
  you imagine** — the reviewer found a `--primary` gap because every mutant I
  wrote attacked logic I had just authored. Seven `dwm-*` scripts remain
  untested; `dwm-brightness` is the highest-value next, as it parses
  `xrandr --verbose` and does arithmetic on it.

- 2026-08-12 — **Epic: roster gap-fill (scope-c) — ALL 4 SUB-TASKS MERGED.**
  Scope file `.claude/tasks/scope-c-roster-gap-fill.md` holds the locked
  decisions; do not re-litigate them.
  - [x] 1. packages — folded into whichever sub-task needed each one
  - [x] 2. xsettingsd — `92eb216`, `ad3c872`
  - [x] 3. udiskie + autorandr — `6b8649e`, `a011220`
  - [x] 4. dwm-colorpicker + dwm-display + ROADMAP reconciliation — `f88d684`,
        `b03573a`
  Three things from this Epic worth carrying: a tool's justification was
  **wrong** and got corrected mid-Epic before any code was written (xsettingsd);
  a **shim that matched a tool's interface but not its output format** made a
  broken script's test green until the reviewer blocked it (colour picker); and
  **enumerated lists went stale three separate times** — the daemon list, rule 6
  itself, and CLAUDE.md's `20-path.zsh` reference.

- 2026-08-12 — **Epic scope-c sub-task 3: udiskie + autorandr** — `6b8649e`,
  `a011220`. Daemons 7 → 9. Two structural splits, both cap-forced: the
  function (57/60) as planned, then the whole file (254/250) into
  `install-session-template.sh`. Three things worth carrying forward: the
  function split was proven equivalent by **byte diff**, which caught two
  defects the green test missed; a stale daemon **enumeration** was removed
  rather than extended, and CLAUDE.md rule 6 now forbids re-adding one; and the
  reviewer caught CLAUDE.md contradicting its own diff because rule 6 was
  written before the late split moved the functions it named.

- 2026-08-12 — **Epic scope-c sub-task 2: xsettingsd** — `92eb216`, `ad3c872`.
  GTK apps now get the theme identity and the Xft rendering keys from one place;
  `reload.sh` gained a 7th target and the daemon set went 6 → 7. Two things
  worth carrying forward: the tool's original justification was **wrong** (the
  "GTK apps keep a stale theme" hole does not exist — `gtk.dcol` already
  documented that GTK re-reads `gtk.css` itself), corrected in the scope file
  and `docs/THEMING.md` before building; and hoisting `theme_conf_get` nearly
  promoted a **fourth** `sed | head -1` SIGPIPE site into shared use.
  `install-restore-theme.sh` hit 286/250 and split into
  `install-restore-theme-identity.sh` (193 + 121).

- 2026-08-12 — **queue items 1 and 2, one closed by being subsumed** —
  `a48de6b`, `59d54d5`. `manifest_has_path <TAG> <path>` now lives in
  `global_fn.sh` and replaces `theme_is_ours` / `theme_backed_up` /
  `app_is_ours`; `install-restore-theme.sh` 248 → **223**, so item 1's split is
  no longer needed — exactly the subsumption item 2 predicted. Direct calls
  beat wrappers on measurement. New `tests/manifest-has-path.sh` (suite 9 → 10)
  proves the regression rather than describing it: shipped shape **5/5** on a
  200k-row manifest, the replaced `| grep -qxF` pipeline **0/5**. Two
  shellcheck findings were real — SC2329 (a test that sources `global_fn.sh`
  must not define its own colour helpers; they are overwritten and become dead
  code) and SC2015 (`cmd && pass || fail` runs both if `pass` fails). Zero
  suppressions. **The post-merge check caught `tests/build.sh` failing on main**
  from a pre-xresources `suckless/slock/config.h` — a gitignored artifact, so
  invisible to both CI and the slot worktree; all five cleared. **This log was
  also misdated `2026-08-10` and renamed with the user's approval** rather than
  self-excepting session-protocol.md's immutability clause.

- 2026-08-10 — **queue items 1–5, closed in one sweep** — `6a0c123`,
  `a47174d`. `install-session.sh` 250 → 192 via a new
  `install-session-report.sh`; CI now *invokes* `tests/lint.sh --strict` and
  `tests/build.sh` rather than reimplementing them; the third and last known
  `pipefail`/SIGPIPE site fixed (old shape reproduced at 0/5, new at 5/5);
  `xrdb -merge` bounded at 10s. The fifth item was **not** the one-line fix it
  was written as — `30-plugins.conf` hardcoded the TPM path in four more
  places, so fixing only the installer would have produced two plugin trees
  instead of one wrong path. Both sides changed together, verified against a
  real tmux 3.7b server, and `tests/tmux-tpm-lockstep.sh` now guards the
  coupling (4 mutants, all caught). Suite 8 → 9. **The queue entry described a
  symptom, not a specification** — worth remembering for the rest of this list.

- 2026-08-08 — **polkit autostart + keybound apps re-tiered** — `51a728d`,
  `24f77fc`. Closed two queue items at once. The polkit agent is launched from
  `autostart.sh` by absolute path (its binary is not on `PATH`, so the
  `command -v` pattern the other five daemons use would have silently never
  fired). `thunar` and `firefox` moved to `desktop.lst` — a **DECISION
  REVERSAL** of `package-tiers`, decided on the criterion written in
  `desktop.lst` rather than the unwritten one I had applied. Adding a sixth
  daemon broke the 60-line cap twice, forcing two provably output-identical
  refactors, and `tests/autostart-daemons.sh` was rewritten to RUN both
  functions rather than parse them.

- 2026-08-08 — **package tiers** — `5a4e681`, `13b6902`. The `core.lst` vs
  `extra.lst` review, five sub-tasks deep. Answer was not a promotion list:
  the two-tier model could not express "serious but must not abort", so
  everything load-bearing sat in best-effort `extra.lst`. Now four tiers
  (`core` 2 / `build` 13 / `desktop` 26 / `extra` 61) plus a closing failure
  summary that names each casualty and what it costs. `core.lst` *shrank* to
  `git`+`zsh` — a hard-fail on a hand-checked name would turn a degraded
  install into none. Six previously-undeclared packages now declared, the
  rule 10 inline-array violation closed, and both `tests/pkglist.sh` and
  `ci.yml` now glob the lists so a fifth tier needs no code change.

- 2026-08-08 — **picom autostart** — `592abb3`. picom added to the
  `autostart.sh` template (first, before the other four daemons) plus a
  matching branch in `session_autostart_report()`; `tests/autostart-daemons.sh`
  now pairs the two daemon sets so the same drift cannot recur. Fixed a
  pre-existing 60-line-cap violation in `install_session_autostart()` in
  passing. **Existing installs still need the line pasted by hand** —
  `autostart.sh` is user-owned (CLAUDE.md rule 6), so the installer only
  reports it.

- 2026-08-07 — **Epic: app / tool / package roster finalization**, all 11
  sub-tasks merged. Scope file:
  `.claude/tasks/scope-b-app-roster-finalization.md` (locked decisions live
  there — do not re-litigate them).
  - [x] 1. zsh: purge HyDE leftovers, retarget at dwm/X11 (+ starship.toml, zoxide) — `97b41b9`
  - [x] 2. `packages/*.lst` final roster + starship adoption + Nerd Font — `1129cf9`
  - [x] 3. alacritty as main terminal (st retained as fallback) — `f5f148a`
  - [x] 4. sxhkd keybind split with dwm — `b8a17e0`
  - [x] 5. screenshot — maim + slop + dmenu mode menu — `b2dcb13`
  - [x] 6. lock / idle — xss-lock + xset + slock — `4ebf84b`
  - [x] 7. status bar blocks — Layout A, 10 blocks + tray (order locked) — `d2a2c57`
  - [x] 8. thunar finalization (archives, thumbnails, defaults, terminal) — `b11fd73`
  - [x] 9. fastfetch + starship theming + cava removal + docs — `d3fa7f1`
  - [x] 10. picom performance tuning (template + base config in lockstep) — `f4a44aa`
  - [x] 11. dynamic scratchpads — dwm patch swap — `9202bfb`

- 2026-08-06 — **Epic: dark-mode-only theming engine (wallbash-for-X11)**,
  all 7 sub-tasks merged. Wallpaper -> ImageMagick colour extraction ->
  dcol palette -> template engine -> live targets (dwm/st/dmenu/slock/
  dwmblocks/dunst/picom/gtk/vim/cava) -> atomic reload. Dark mode only.
  Scope file: `.claude/tasks/scope-a-theming-engine.md`.
  - [x] 1. xresources patches (dwm/st/dmenu/slock) — commit `1f43276`
  - [x] 2. colorgen.sh (ImageMagick dark-mode dcol extraction) — `b98dde8`
  - [x] 3. apply-templates.sh (template engine) — commit `1d57148`
  - [x] 4. templates + base dunstrc/picom.conf — commit `27b2e40`
  - [x] 5. reload.sh (atomic ordered reload) — commit `5e79ceb`
  - [x] 6. wallpaper.sh / theme-apply.sh + keybinds — commit `f85bb8a`
  - [x] 7. static dark theme + packaging + docs — commit `ff1ca5c`
- 2026-08-06 — vim + cava app templates (post-Epic follow-up) — `399c412`
- 2026-08-05 — uninstall/versioning/migrations subsystem (VERSION,
  scripts/version.sh, global_fn.sh, uninstall.sh, migrations framework)
- 2026-08-05 — CI tooling (shellcheck/shfmt/markdownlint, pre-commit,
  GitHub Actions, tests/)
- 2026-08-05 — post-push verification audit (3 parallel read-only audits,
  bugs found and fixed in version.sh/install-restore.sh/.shellcheckrc)

## Completed

*(see `.claude/changes/` dated logs for full history predating this file)*

## Deferred

*(none)*
