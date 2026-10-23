# Scope K — integrated desktop

Opened 2026-10-23. The user asked what would make the system feel like an
integrated desktop. Of a 13-item survey they picked items 1, 2, 3, 9, 10, 12
and 13. Items 4–8, 11 (media block, window switcher, quick-settings hub,
audio-device switcher, keyboard layout, first-login welcome) are **not**
in scope. They were not rejected; they wait for a later ask.

Every package below was checked against the live Void repodata on
2026-10-23. Each one's `.xbps` file list was read for the binary or path
this scope relies on (rule 8).

## Locked decisions (user, 2026-10-23)

1. **Keyring = gnome-keyring 48.0, unlocked by PAM at the ly login.**
   `pam_gnome_keyring.so` ships in the package (`/usr/lib/security/`).
   Only the `secrets` component runs. Rejected: gnome-keyring with no PAM
   (a password prompt every session), KeePassXC (35 MB, unlocked by hand),
   kwallet.
2. **Qt = qt5ct + qt6ct, with a colour scheme generated from the
   wallpaper** by a `.dcol` template, so Qt follows the wallpaper the way
   GTK does. Both plugins exist (`/usr/lib/qt{5,6}/plugins/platformthemes/
   libqt{5,6}ct.so`). Rejected: a fixed Kvantum theme, adwaita-qt (fixed
   colours), installing both.
3. **Clock click = a `yad --calendar` popup** (yad 14.2), themed by
   gtk.css. Rejected: calcurse in a floating terminal, an improved
   notification.
4. **Sounds = `pw-play`** (ships with pipewire 1.6.9, no new player) plus
   `sound-theme-freedesktop` 0.8 for the files. Rejected: canberra-gtk-play
   (`libcanberra-utils`).
5. **Cursor hiding = `unclutter-xfixes` 1.6**, which hides the cursor after
   idle time. Rejected: xbanish (hides it while typing).

## Assumptions (Type B, stated, not asked)

- **A1 — dex reads `~/.config/autostart` only**, never `/etc/xdg/autostart`.
  Scope F made `autostart.sh` start blueman, nm-applet, lxpolkit and
  xdg-user-dirs explicitly, and gnome-keyring ships three
  `/etc/xdg/autostart` entries, so `dex -a` over the system directory
  would start each of them twice. dex 0.10.1 is the only packaged runner.
  It needs python3, which `extra.lst` already pulls in (python3-pip).
  If incorrect, the alternative is a shell parser of our own.
- **A2 — the dim-before-lock is an xss-lock `--notifier` that fades with
  gamma** and is cancelled by any input. It must restore the gamma that
  was there before the fade (night light and `dwm-brightness` both set it),
  never 1.0. Rejected: a backlight fade, which only works on laptops.
- **A3 — tiers:** gnome-keyring and qt5ct/qt6ct go in `desktop.lst`, since
  plaintext secrets and unthemed Qt apps both fail silently. Each needs a
  consequence comment (rule 10). The rest go in `extra.lst`.

## Slots (1 first; the rest are independent)

1. `keyring` — gnome-keyring-daemon `--components=secrets` from the session.
   This is a rule-6 three-place change if it goes in autostart.sh. If it
   goes in `.xinitrc` (it has to be on the D-Bus session bus before the
   apps start), it needs the xinitrc report paste lines instead.
   `pam_gnome_keyring` goes in ly's PAM file: `auth optional`, plus
   `session optional auto_start`. **Open, to settle in the slot:** who owns
   `/etc/pam.d/ly` (the ly build's LYBUILD rows?), and how an edit there
   survives a ly rebuild and is reverted by uninstall (SYSFILE contract:
   only while unedited). `dots doctor` must ask the bus for
   `org.freedesktop.secrets`, not just check that the package is installed
   (the lesson from the portal work). It has to be verified in the Void VM:
   a login with the password must unlock the keyring with no prompt.
2. `qt-theme` — `QT_QPA_PLATFORMTHEME` set for the whole X session.
   **Open:** whether a single value covers Qt5 and Qt6 apps; check the
   plugin keys in both `.so` files. qt5ct.conf/qt6ct.conf are rewritten by
   their GUIs, so they are COPIED and claimed, never symlinked (the
   dunst/picom rule). A new `always/` template writes the colour scheme;
   read `config/theme/templates/always/README.md` first.
3. `xdg-autostart` — `dex -a -s ~/.config/autostart` at login (A1). This is
   a rule-6 three-place change (one-shot).
4. `desktop-sounds` — login, notification, volume tick (`dwm-osd`) and
   screenshot shutter, through `pw-play`. One on/off switch. Focus mode
   (`dwm-notify`) mutes notification sounds.
5. `idle-dim` — A2, in `dwm-lock --daemon`'s xss-lock line.
   `tests/` must fake xrandr (fake-binary memory), never the live screen.
6. `calendar-popup` — `dwm-clock` button 1 toggles a `yad --calendar`
   placed under the clock. It needs a floating rule in dwm `rules[]`
   (WM_CLASS read with xprop, not guessed) and the `dwm-runtime` floating
   check.
7. `cursor-hide` — `unclutter-xfixes` started from autostart (rule-6
   three-place). It is an X client, so it dies with the server and needs no
   `dots_session_end` line.

## Findings (2026-10-23, slot 1 planning)

- **Slot 1's PAM question is answered: no PAM edit is needed.** ly's stock
  `res/pam.d/ly-linux` at the pinned commit `afb1dc6`, placed as
  `/etc/pam.d/ly` (a LYBUILD row), already carries
  `-auth optional pam_gnome_keyring.so` and `-session optional
  pam_gnome_keyring.so auto_start`. The leading `-` makes PAM skip the
  module while it is not installed, so installing gnome-keyring is what
  turns the unlock on. A ly rebuild re-places the same lines.
- **No session line is needed either.** gnome-keyring ships
  `org.freedesktop.secrets.service` (`--start --foreground
  --components=secrets`), so the session bus activates it on the first
  request, and `--start` attaches to the daemon PAM unlocked. Existing
  installs get the keyring with no `.xinitrc` or `autostart.sh` change.
  The `/etc/xdg/autostart` entries are `OnlyShowIn=GNOME;Unity;MATE;`,
  which is one more reason A1 holds.
- gnome-keyring also ships a Secret portal backend (`gnome-keyring.portal`).
  `portals.conf` routes only `default=gtk`, which has no Secret portal, so
  Flatpak apps would get no keyring until the file names it.
