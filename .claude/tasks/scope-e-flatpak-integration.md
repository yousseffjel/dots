# Scope E — Flatpak integration

Opened 2026-10-06. **Blocked on `slot/xdg-portal-gtk`** — that slot ships the
gtk portal backend, `portals.conf` and the dconf `prefer-dark` scheme this
work builds on. Open `slot/flatpak-integration` only after it merges.

## Locked decisions (user, 2026-10-06)

1. **Sequencing:** portal slot first, then a new slot on top. Not folded in.
2. **flatpak package + Flathub auto-added** (`--user` remote). This is an
   explicit rule-4 exception, the second after `skidnik/clipmenu`; CLAUDE.md
   rule 4 must record it in the same slot.
3. **Overrides, all four**, via `flatpak override --user`, each tracked in the
   install manifest and reverted by uninstall only if it still holds our value
   (same contract as the portal slot's DCONF rows):
   - `--filesystem=~/.local/share/icons:ro` — vendored Bibata + Papirus
   - `--filesystem=xdg-config/gtk-3.0:ro` — settings.ini + wallpaper gtk.css
   - `--env=GTK_THEME=...` — chosen despite the caveats below
   - `--filesystem=xdg-config/fontconfig:ro` — no-op today (dots ships no
     fontconfig); kept as the user asked
4. **No Flatseal.** Scripted only; `flatpak override --user --show` inspects.

## Open for /explore

- GTK_THEME value: `Adwaita:dark` hardcodes dark for every theme (fine while
  all four `theme.conf` say Adwaita-dark), and libadwaita/GTK4 apps can
  misrender under it. Check whether it should come from `theme.conf` and be
  re-written on `dots theme` switch.
- Does Flatpak already expose `~/.local/share/icons` via `/run/host/user-share`
  and XCURSOR_PATH? If so, override 1 may be partly redundant — verify, don't
  assume.
- Tier: flatpak in `desktop.lst` or `extra.lst` (rule 10 — is its absence silent?).
- Fedora Server has no flatpak preinstalled; Workstation has the `fedora`
  remote already. Package names checked against packages.fedoraproject.org.
- Tests must shim `flatpak` on PATH — never touch the real user overrides.

## Explore outcome (2026-10-06) — decisions appended, not interleaved

5. **DECISION REVERSAL of 3's `GTK_THEME`: dropped.** GTK calls it a debugging
   variable, and set globally it breaks GTK4/libadwaita Flatpak layouts
   (gitlab.gnome.org/GNOME/gtk/-/issues/5661). Redundant here: GTK3 gets
   Adwaita-dark from xsettingsd over the X socket + `gtk-3.0:ro`; GTK4 gets dark
   from the portal colour scheme (f831138). Three filesystem overrides ship.
6. **Flathub remote is reverted by uninstall** — manifest row only when the
   remote did not already exist; removed only if no installed ref still uses it.
   (The clipmenu COPR has no such row today; not changed by this scope.)
7. **`flatpak` goes in `extra.lst`**, next to the portal block.

Findings: icons override is NOT redundant — the user icon dir is mounted at
`/run/host/user-share/icons`, but only newer runtimes put that on the cursor
search path (freedesktop-sdk MR 6777, merge status unconfirmed); the real-path
mount works on any runtime. `install-restore-apps.sh` is at 220/250 and
`tests/install-uninstall-symmetry.sh` at 223/250 — new code needs its own file.

## VM verification (2026-10-06, after merge) — two pre-existing bugs found

Overrides verified on the VM: `flatpak override --user --show` lists the three
`:ro` grants; inside the sandbox `~/.config/gtk-3.0` (gtk.css, settings.ini)
and `~/.local/share/icons/Bibata-Modern-Classic` are visible, and flatpak
mirrors the gtk-3.0 grant into the per-app `$XDG_CONFIG_HOME` too. But both
test apps rendered LIGHT:

- **GTK3 (Mousepad):** `theme.conf` says `gtk_theme=Adwaita-dark`. GTK 3.24
  has no such built-in (gtk/gtkcssprovider.c `_gtk_css_provider_load_named`:
  an unresolved name is retried WITHOUT the variant, then falls back to plain
  Adwaita), and Fedora 44 has no `gnome-themes-extra`, so the
  `gtk-application-prefer-dark-theme=1` already in settings.ini is discarded.
  `flatpak run --env=GTK_THEME=Adwaita:dark` rendered dark. Very likely hits
  native GTK3 apps on the host too. Fix: `gtk_theme=Adwaita` in all four themes.
- **GTK4 (Text Editor):** the portal never starts — `gdbus ... Settings.ReadOne`
  → "Could not activate remote peer 'org.freedesktop.portal.Desktop': startup
  job failed". xdg-desktop-portal 1.22.1's unit has
  `Requisite=graphical-session.target`, which a startx/dwm session never
  activates. So NO portal works in a dwm session (the f831138 portal work
  installed it but it was never exercised under real systemd).

## Decisions (user, 2026-10-06, round 3)

8. **Portal fix: a session target.** A user unit `dots-session.target`
   (`BindsTo=graphical-session.target`), started from ~/.xinitrc after the
   systemd environment import and stopped when dwm exits. Existing installs'
   ~/.xinitrc is user-owned (rule 6) → a report line telling them what to
   paste. Rejected: a drop-in resetting `Requisite=` (fights upstream, never
   stopped at logout, next unit with the same Requisite breaks again).
9. **Two slots:** `slot/gtk3-dark-theme-name` (Small) and
   `slot/portal-session-target` (Medium; include a doctor check that the
   portal actually ANSWERS, not just that the package is installed).
10. **Flatpak apps on PATH for dmenu:** add the user and system
    `flatpak/exports/bin` to PATH in `config/zsh/.zshenv`. Micro, own commit.
11. **GTK3 fix: restore the gnome-themes-extra shim** (user, round 4) —
    `~/.local/share/themes/Adwaita-dark/gtk-3.0/gtk.css`, one @import of GTK3's
    built-in dark stylesheet, plus a `xdg-data/themes:ro` Flatpak grant.
    Supersedes the "rename to `Adwaita`" fix in the VM section above: GTK4
    treats `Adwaita-dark` as a built-in alias, so a rename would turn plain
    GTK4 apps light. Slot `gtk3-adwaita-dark-shim` (renamed from decision 9's
    `gtk3-dark-theme-name`).
