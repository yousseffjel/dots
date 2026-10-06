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
