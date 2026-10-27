# Desktop integration

The pieces a full desktop environment provides without being asked for, and
how a dwm session gets each one. Theming has its own document
([THEMING.md](THEMING.md)); this one covers everything else that has to
happen behind the scenes.

## Keyring

Browsers, VS Code, Element, git credential helpers and NetworkManager's
applet keep passwords and tokens in the **Secret Service**, a D-Bus API. With
no Secret Service running, each app either writes them to disk in plain text
or asks for a keyring that never appears. dots ships **gnome-keyring**
(`packages/desktop.lst`) to provide it, and nothing in the session has to
start it:

1. **ly's login unlocks it.** ly's stock PAM file, which the services stage
   installs as `/etc/pam.d/ly` with the ly build, already contains
   `-auth optional pam_gnome_keyring.so` and
   `-session optional pam_gnome_keyring.so auto_start`. The `-` prefix tells
   PAM to skip a module that is not installed, so these lines did nothing
   until gnome-keyring was installed. Now ly passes your login password to
   the keyring, which unlocks the `login` keyring (creating it on your first
   login after the install).
2. **The session bus starts the secrets part on demand.** gnome-keyring ships
   `org.freedesktop.secrets.service`, so the first app that asks for a secret
   makes the bus run `gnome-keyring-daemon --start --components=secrets`.
   That daemon finds the one PAM unlocked and hands the request to it. This
   is why `autostart.sh` and `~/.xinitrc` need no new line, and why an
   existing install gets the keyring with nothing to paste.
3. **Flatpak apps** reach it through the Secret portal.
   `config/xdg-desktop-portal/portals.conf` routes that one interface to
   gnome-keyring. The gtk backend serves every other interface but has no
   Secret portal of its own.

Only the `secrets` component runs. gnome-keyring's SSH and PKCS#11
components are not started. gnome-keyring's own `/etc/xdg/autostart` entries
are `OnlyShowIn=GNOME;Unity;MATE;`, and a dwm session does not read that
directory anyway.

**Check it:** `dots doctor` reads the default collection's `Locked` property
from the Secret Service. **ok** means apps can store secrets without a prompt.
To try it by hand (`secret-tool` is in Void's `libsecret` package):

```sh
printf 'hello' | secret-tool store --label probe dots probe
secret-tool lookup dots probe     # prints hello, and nothing asked for a password
secret-tool clear dots probe
```

**When the doctor says it is locked**, the keyring's password is no longer
your login password. That happens after a password change made with
`passwd` rather than through the login screen, or with a keyring created
before gnome-keyring could see the password. Open the keyring once when
asked, then change its password to your login password in **Seahorse**
(`sudo xbps-install seahorse`, then "Passwords and Keys"). Or delete
`~/.local/share/keyrings/login.keyring` and log in again through ly to start
a fresh one; any secrets stored in it are lost.

**Not covered:** logging in on a text console and running `startx`. That
login goes through Void's `/etc/pam.d/login`, which dots does not edit, so
the first app that needs a secret asks for the keyring's password once per
session. ly's autologin (`ly-autologin`) has no password to hand over at
all, so it behaves the same way.

## Qt apps

Qt apps (VLC, qBittorrent, KeePassXC, OBS, anything KDE) do not read GTK's
theme. Without help they open in Qt's own light Fusion palette next to dark
GTK apps. dots themes them through **qt5ct** and **qt6ct**
(`packages/desktop.lst`), from the same wallpaper palette as everything
else:

| Piece | Where | Written |
| --- | --- | --- |
| `QT_QPA_PLATFORMTHEME=qt5ct` | `config/zsh/.zshenv` | every session; a value already set (another desktop's) is kept |
| the colours | `~/.cache/dots/theme/qt-colors.conf` | by `always/qt.dcol`, on every wallpaper change |
| `qt5ct.conf`, `qt6ct.conf` | `~/.config/qt5ct/`, `~/.config/qt6ct/` | by the installer, and again by a theme switch: the colour file's path, the theme's icons and font, the Fusion style |

One value covers both Qt versions: each plugin answers to `qt5ct` and to
`qt6ct`. Fixed-width text is not set. It follows fontconfig's `monospace`,
which `config/fontconfig` already points at Cascadia Code NF.

**Open apps re-theme on their own**, within a couple of seconds of a
wallpaper change. qt5ct and qt6ct watch their config directory, so the
template's post-command re-places each conf with an identical copy, and the
directory watcher sees that. Editing the colour file in place would go
unseen.

**Your own settings are kept.** A `qt5ct.conf` or `qt6ct.conf` that existed
before the install is never written to and never removed. Changing a setting
in the qt5ct/qt6ct GUI also works, but the next `dots theme` switch rewrites a
conf dots wrote. To keep your own for good, remove its `THEME` row from
`~/.local/state/dots/manifest`: dots then treats the file as yours, and never
writes or removes it again. Pointing `color_scheme_path` at a scheme of your
own also works, though only until the next switch.

**Check it:** `dots doctor` reads `QT_QPA_PLATFORMTHEME` from the running dwm
session's environment rather than the terminal's, then checks that both confs
name a colour file that exists. A new install needs one log out and back in
for the variable to reach the session.

**Not covered:** Kvantum (an SVG theme engine with a richer look, but fixed
colours) is not installed. Qt's own file dialogs are used, not the portal's
GTK one (`standard_dialogs=default`).

## Autostart apps

An app's own "start at login" switch (Syncthing, Discord, Nextcloud,
KeePassXC, a Flatpak through the Background portal) writes a `.desktop` entry
to `~/.config/autostart`. A desktop environment reads that directory at
login. dwm does not, so `autostart.sh` runs **`dwm-xdg-autostart`**, which
hands each entry to **dex** (`packages/desktop.lst`). dex handles `Exec`,
`TryExec`, `Hidden` and `OnlyShowIn`/`NotShowIn`. A dwm session sets no
`XDG_CURRENT_DESKTOP`, so an entry marked for one desktop only (GNOME, KDE)
is skipped.

```sh
dwm-xdg-autostart --list     # what would start, starting nothing
dwm-xdg-autostart --force    # start them again in this session
```

Three things it adds on top of dex:

- **Once per login.** dwm runs `autostart.sh` again after every restart, and
  every wallpaper change restarts dwm. The script records the session (the
  D-Bus address `~/.xinitrc` starts, or dwm's PID and start time when there
  is no bus) under `$XDG_RUNTIME_DIR/dots/`, and does nothing on a restart.
- **One entry at a time.** dex 0.10.1 stops the whole run at the first entry
  it cannot parse (a `Hidden=maybe`), so each entry gets its own run, and a
  broken one is reported by name while the rest start.
- **`X-GNOME-Autostart-enabled=false` keeps an app off.** GNOME-style apps
  use it to turn their own autostart off, and dex ignores it.

**Only `~/.config/autostart`.** `/etc/xdg/autostart` holds entries for
desktop components that `autostart.sh` already starts itself, such as
nm-applet, blueman and the polkit agent, so reading it would start them
twice. To stop one of those, edit `autostart.sh`. To stop an app you enabled,
use its own switch, or delete its file from `~/.config/autostart`. An entry
there for something `autostart.sh` already starts (an `nm-applet.desktop` of
your own, say) starts a second copy.

## Sounds

The desktop makes the sounds a desktop environment makes, from the
freedesktop sound theme (**sound-theme-freedesktop**, `packages/desktop.lst`)
played through PipeWire's **`pw-play`**:

| When | Sound | Played by |
| ---- | ----- | --------- |
| You log in | `service-login` | `autostart.sh` (`dwm-sound --login`) |
| A notification shows | `message-new-instant`; `dialog-warning` when critical | dunst's `[dots_sound]` rule (`dwm-sound-notify`) |
| A volume key raises or lowers (mute makes no tick) | `audio-volume-change` | `config/sxhkd/sxhkdrc` |
| A screenshot is delivered | `screen-capture` | `dwm-screenshot` |

```sh
dwm-sound off       # silence all of them; `dwm-sound on` brings them back
dwm-sound status    # on or off
dwm-sound bell      # play any sound of the theme by name
```

**Focus mode is silent.** dunst runs a rule's script only for a notification
it shows (`always_run_script = false`), and focus mode holds every
notification back, critical ones too. When it ends, the held notifications
show and sound once, not once each (a critical one among them has its own
sound). Each sound plays one at a time: if the same one is still playing, a new request for it is dropped, so a
held volume key or a burst of notifications cannot pile up. Low-urgency
notifications are silent. The volume pop-up and the screenshot confirmation
are both low, because their own sounds already played.

**Once per login.** dwm runs `autostart.sh` again after every restart, so the
login chime remembers the session as `dwm-xdg-autostart` does (above), and
waits up to five seconds for PipeWire, which `~/.xinitrc` starts just before
dwm.

**Your own sounds.** A file of the same name under
`~/.local/share/sounds/freedesktop/stereo/` (`.oga`, `.ogg` or `.wav`) replaces
the stock one.

An existing install gets the notification sound with its next generated
dunstrc (`dots wallpaper --random`, or `dots theme dark`). Until then,
`dots doctor` warns about it. It also checks that `pw-play` and the sound
theme are present. An existing `autostart.sh` gets the `dwm-sound --login`
line to paste on the next installer run.

## Calendar

A left-click on the clock opens this month's calendar under it; a second
click, Escape, or focusing another window closes it. It is
`config/dwm/bin/dwm-calendar`, a GtkCalendar in a small window, so it takes
the wallpaper's colours from `gtk.css` like every other GTK app.

It needs **python3-gobject** (`packages/extra.lst`). Without it the click
shows the month as a notification, as it did before. The window's class is
`dots-float-calendar`, which the `dots-float-` rule in dwm's `rules[]` already
floats, so no dwm rebuild is needed.

Not yad, which scope K first chose: on Void yad depends on `libwebkit2gtk41`
(122 MB) for its HTML dialog, and zenity on webkitgtk 6.0. The script needs
nothing the desktop does not already have but python3-gobject (671 KB).

## Hidden pointer

The mouse pointer hides after 5 seconds without moving, so it never sits over
the text you are reading or typing; the next move brings it back.
`autostart.sh` starts **unclutter-xfixes** (`packages/extra.lst`, binary
`unclutter`) with `--timeout 5`. Change the number in your `autostart.sh`, or
delete the line to keep the pointer always visible. An existing
`autostart.sh` gets the line to paste on the next installer run.
