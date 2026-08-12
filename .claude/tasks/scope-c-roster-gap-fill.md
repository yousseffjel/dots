# Scope C — roster gap-fill (ROADMAP §3's last `❌ add` rows)

Epic decomposition per `.claude/rules/foundations/task-planning.md` §
"Any -> Epic". Source request: user, 2026-08-12, in-chat. The tool roster
was settled by a comparison pass in that same session; the decisions it
produced are recorded under "Locked decisions" below so no sub-task has to
re-derive them.

"Layers" here means the same subsystem areas Scope A and Scope B used:
`config/<app>/` (deployed config), `config/theme/templates/` (theming),
`packages/` (dnf lists), `scripts/install-*.sh` (integration), `tests/`,
and `docs/` + `KEYBINDINGS.md` + `ROADMAP.md` (markdown).

---

## Locked decisions (do not re-litigate)

1. **`xcolor` is NOT an option — it does not exist in Fedora.** The only
   `xcolor` in the repos is `texlive-xcolor`, a LaTeX package. Verified
   against packages.fedoraproject.org 2026-08-12. ROADMAP §3 names it and
   is wrong. The colour picker is a **`config/dwm/bin/dwm-colorpicker`
   script** instead — `xdotool getmouselocation` -> `maim -g 1x1` ->
   ImageMagick `%[hex:p{0,0}]` -> xclip + a dunst swatch. maim,
   ImageMagick and xclip are already installed; this matches the seven
   existing `dwm-*` dmenu scripts and avoids a GUI app for a one-shot
   query. `gpick` (0.4, in Fedora 43/44) goes in `extra.lst` for anyone
   who wants a real palette tool. `gcolor3` was considered and dropped as
   a redundant middle ground.
2. **`xsettingsd` is in, and it is the highest-value item.** It closes a
   real hole: the engine re-themes dwm, st, dmenu, dunst, picom,
   alacritty and the prompt on every wallpaper change, but GTK reads
   `settings.ini` only at startup, so already-running GTK apps keep the
   old theme until restarted. An XSETTINGS daemon lets `reload.sh` SIGHUP
   them live. `gnome-settings-daemon` (drags GNOME) and `xfsettingsd`
   (drags xfconf + XFCE session bits) were both rejected as too heavy.
3. **`udiskie` is in, and it is not redundant with `thunar-volman`.**
   volman only auto-mounts while Thunar is running, and nothing
   daemonises Thunar — `autostart.sh` has no `thunar --daemon` line — so
   that roster row is unmanned today. udiskie is standalone, has a tray
   icon (the systray patch is vendored), notifies through dunst, and
   exposes `udiskie-mount`/`udiskie-umount` for a future dmenu wrapper.
   Adding `thunar --daemon` instead was the considered alternative.
   `udevil`/`devmon` rejected as unmaintained.
4. **`autorandr` is in; `arandr` is OUT.** They are complementary, not
   competing: arandr is a GTK GUI for authoring a layout once, autorandr
   is the CLI that fingerprints displays by EDID and re-applies a saved
   profile **on hotplug**. Only the second one does something a script
   cannot. A `config/dwm/bin/dwm-display` dmenu script covers the manual
   presets, so arandr earns nothing.
5. **`xdg-desktop-portal-gtk` is OUT for now.** It is the only sane
   backend for a non-GNOME/KDE X11 session (xdp-kde drags Qt/KF6 and
   violates Scope B's locked decision 3; xdp-wlr is Wayland-only), but it
   only pays off with Flatpak, and under X11 Firefox and Chromium use
   their own file dialogs. If it is ever added, the package alone is not
   enough: `XDG_CURRENT_DESKTOP` must be exported and
   `~/.config/xdg-desktop-portal/portals.conf` must set `default=gtk`, or
   file choosers hang rather than fail loudly.
6. **`xdotool` is a dependency, not a feature.** Nothing in the repo uses
   it today. It is in solely because sub-task 4's colour picker needs
   `getmouselocation`. It therefore belongs in `desktop.lst` (a dead
   picker keybind is exactly the silent failure that tier exists for). If
   sub-task 4 is ever dropped, drop xdotool with it.

## Fedora availability (verified 2026-08-12, rule 8)

All against packages.fedoraproject.org; active branches are 43, 44 and
Rawhide (41 and 42 are EOL — note `ci.yml` still pins `fedora:41`).

| Package | Version | Branches |
| --- | --- | --- |
| `xsettingsd` | 1.0.2 | 43, 44, Rawhide |
| `udiskie` | 2.6.2 | 43, 44, Rawhide |
| `autorandr` | 1.15 | 43, 44, Rawhide |
| `xdotool` | 3.20211022.1 | 43, 44, Rawhide |
| `gpick` | 0.4 | 43, 44, Rawhide |
| ~~`xcolor`~~ | — | **does not exist** (only `texlive-xcolor`) |

---

## Sub-tasks

Order is deliberate. Sub-tasks 2 and 3 both edit
`scripts/install-session.sh`, so they must not run as concurrent slots —
`session-init` would flag the `## Scope` overlap, but sequencing is
cleaner than resolving it.

- [ ] **1. Packages** — `xsettingsd`, `udiskie`, `autorandr`, `xdotool`
  into `desktop.lst` with consequence comments; `gpick` into `extra.lst`.
  *(Each sub-task folds in its own package line instead, where that keeps
  the slot self-contained — see sub-task 2.)*
- [ ] **2. xsettingsd theming integration** — new
  `config/theme/templates/always/xsettingsd.dcol`, the manifest claim and
  parent-dir mkdir in `install-restore-theme.sh`, a 7th reload target in
  `reload.sh`, an autostart line, plus `CLAUDE.md` and `docs/THEMING.md`.
  Folds in its own `desktop.lst` line. **Unblocked by the 27 lines of
  headroom from `manifest-has-path` (2026-08-12).**
- [ ] **3. udiskie + autorandr** — daemon set 6 -> 8 in
  `install-session.sh` + its paired `install-session-report.sh` branch +
  `tests/autostart-daemons.sh`; autorandr's systemd user unit in
  `install-services.sh`.
- [ ] **4. dwm-colorpicker + dwm-display** — two new `config/dwm/bin/`
  scripts, their `sxhkdrc` binds, `KEYBINDINGS.md`, and the `ROADMAP.md`
  §3 rows this Epic closes (including the `xcolor` correction).

## Out of scope for this Epic

- ROADMAP §9's priority list (entirely closed) and §3's stale picom row —
  a separate documentation pass, already its own queue item.
- The `fedora:41` EOL CI pin — own queue item.
- Any Qt theming, per Scope B locked decision 3.
- `thunar --daemon`, considered and rejected in favour of udiskie.
