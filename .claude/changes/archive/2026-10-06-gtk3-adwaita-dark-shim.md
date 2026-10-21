# gtk3-adwaita-dark-shim
Date: 2026-10-06
Files: 23 tracked + 4 new | Lines: +205/-47 tracked, +270 in the new files

## What changed
- `assets/themes/Adwaita-dark/gtk-3.0/gtk.css` (new): gnome-themes-extra's
  one-line GTK3 theme, verbatim (upstream `5a09becd`, LGPL-2.1):
  `@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");`.
  `assets/themes/README.md` gives its source, the GTK code path, and why the
  name was kept.
- `scripts/install-restore-gtk3-shim.sh` (new), sourced by
  `install-restore-theme.sh` and called right after `restore_cursor_theme`.
  `restore_gtk3_shim`:
  - copies the shim to `~/.local/share/themes/Adwaita-dark` only when nothing
    is there, with a THEME row (`uninstall_theme` already `rm -rf`s directory
    rows);
  - leaves an existing directory alone and unclaimed;
  - clears a failed partial copy;
  - handles `--dry-run`, and warns when the asset is missing.
- `scripts/install-restore-flatpak.sh`: a fourth grant,
  `xdg-data/themes:ro`, so sandboxed GTK3 apps see the shim.
- `scripts/doctor-session.sh` + `doctor.sh`: `check_gtk3_theme` reads
  `gtk-theme-name` from settings.ini. It reports ok for a GTK3 built-in
  (Adwaita, HighContrast, HighContrastInverse) or a `gtk-3.0/` theme dir in
  the user data dir, `~/.themes` or `XDG_DATA_DIRS`, and warns otherwise. The
  doctor's Flatpak line now says "cursor, icons, GTK3 theme and gtk.css".
- Tests:
  - `tests/gtk3-adwaita-dark-shim.sh` (new, 12 checks). It covers deploy,
    re-run, the user's own theme dir, dry-run, a missing asset, a failed copy
    and uninstall.
  - It also checks that every `theme.conf` `gtk_theme` is a GTK3 built-in or
    a shim, that FLATPAK_GRANTS exposes `xdg-data/themes`, and that the
    imported resource is in libgtk-3.
  - The symmetry test now requires the shim's THEME row, which proves it is
    wired in. The doctor sandbox gets settings.ini and the shim from the
    installer's own functions, plus 3 new checks.
  - `tests/flatpak-integration.sh` reads its counts and sets from
    FLATPAK_GRANTS instead of four hard-coded values.
- `tests/lib/sealed-path.sh`: `fake()` removes its target before writing.
- Docs: the "Adwaita-dark is a GTK3 built-in" claim was corrected in all four
  `theme.conf` files, `packages/extra.lst`, `docs/THEMING.md`, `HANDOFF.md`
  and `CLAUDE.md` (with a "do not rename to `Adwaita`" note and map rows).
  Also updated: `docs/UNINSTALL.md` step 4 + 5b, `CHANGELOG.md` (Fixed entry,
  four grants), `ROADMAP.md`, `TESTING.md`.
- `.claude/tasks/scope-e-flatpak-integration.md`: the VM findings and
  decisions 8–11. They were written on main after the flatpak-integration
  merge and folded into this slot.

## Why
The VM check of flatpak-integration showed Mousepad (Flatpak GTK3) light.
`flatpak run --env=GTK_THEME=Adwaita:dark` was dark. The host's
`/usr/share/themes` held only Default/Emacs/Raleigh. The cause was in GTK3 and
in the theme files, not in Flatpak, and it has affected native GTK3 apps on
Fedora 44 since `theme.conf` was wired up (2026-08-12).

## Key Technical Decisions
- **Restore the shim, keep the name** (scope-e decision 11, the user's choice).
  The rejected fix renamed `gtk_theme` to `Adwaita`. GTK4's
  `gtkcssprovider.c` accepts `Adwaita-dark` as an alias for its dark Default,
  and no XSETTINGS key carries prefer-dark in GTK3 or GTK4 (checked in
  `gdk/x11/gdksettings.c` for both). So a rename would turn plain GTK4 apps
  light, unless dots also managed a `gtk-4.0/settings.ini`, which makes
  libadwaita warn on every start.
- **Root cause, from GTK source.** In gtk-3-24 `gtk/gtkcssprovider.c`,
  `_gtk_css_provider_load_named` checks the built-in resource first, then
  theme dirs. Otherwise "Fall back! Fall back!": it retries without the
  variant, then loads plain Adwaita. So `gtk-application-prefer-dark-theme=1`
  was lost too.
- **The shim is copied, not symlinked.** This follows the cursor pattern, so
  uninstall works by manifest row and the user's copy is never linked into the
  repo.

## Assumptions
- Type B: GTK3 inside Flatpak searches a theme dir exposed by
  `xdg-data/themes:ro`. flatpak did mirror the `xdg-config/gtk-3.0` grant into
  the per-app config dir on the VM, so the same is likely for xdg-data. **Not
  verified on the VM.**
- Type B: GTK2 is unaffected. It searches `~/.themes` and
  `/usr/share/themes`, not `~/.local/share/themes`, and the shim has no
  `gtk-2.0/` anyway.

## Test coverage
- `tests/run-tests.sh`: 40 OK, 0 FAIL. `tests/lint.sh` clean.
- Mutation testing on copies: 11/11 caught, each by its own assertion. The
  failed-copy cleanup mutant was also caught by its own case. The mutants
  covered the claim guard, the THEME row, dry-run, missing-asset abort,
  unwired restore, a dropped grant, a renamed `theme.conf`, a wrong `@import`
  path, and three doctor mutants.
- On the dev host (Arch, gtk3 3.24.52), `gtk-contained-dark.css` is present
  in libgtk-3. There is no `gresource` binary there, so the test used its
  weaker name-match path.
- Real flatpak 1.18.4 round trip with four grants: byte for byte.
- **Not run on Fedora or the VM.**

## Incident
- **A test nearly overwrote `/usr/bin/cp` on the dev host.** The failed-copy
  case did `cp -a` on the sealed bin dir, which copies its SYMLINKS to the real
  tools. `fake()` then `printf >`'d through the `cp` link. Only root ownership
  of `/usr/bin/cp` stopped it ("Permission denied"). `/usr/bin/cp` was checked
  afterwards: root-owned, unchanged, coreutils 9.12.
- Fixed at the source: `fake()` now `rm -f`s its target first. All 15 tests
  using `sealed-path.sh` re-run OK.

## Follow-ups
- On the VM after merge:
  - run `--only-restore`;
  - Thunar and `flatpak run org.xfce.mousepad` should be dark with no
    `GTK_THEME`;
  - `dots doctor` should show `GTK3 theme Adwaita-dark found in …`.
- Next slot: `portal-session-target` (scope-e decisions 8–9). GTK4/libadwaita
  apps stay light until it lands.
- Micro: flatpak `exports/bin` on PATH (decision 10).
