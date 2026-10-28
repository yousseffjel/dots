# Troubleshooting

## Start with `dots doctor`

```sh
dots doctor
```

It checks the install, the packages, the running X session, the theme and the hardware, and changes nothing. Each
check is one of:

- **ok** — fine.
- **warn** — degraded; the desktop still works.
- **fail** — something the install promises is broken.
- **skip** — cannot be checked here, or not needed here (for example, the desktop portal checked from outside the
  dwm session).

Every line that is not ok names the problem and, where there is one, the command that fixes it. It exits non-zero
when anything failed, so `dots doctor || ...` works in a script.

For a script, or to compare two machines:

```sh
dots doctor --tsv     # status<TAB>section<TAB>id<TAB>detail, one line per check
```

Run it from a terminal inside your desktop session: the session, theme and keyring checks need the running session.

The installer's own output is kept in `install.log` at the root of the repo, one run after another.

## Common problems

These are all issues the repo has met and documented. Most were fixed in a later version; the entry says what an
older install needs to do.

### The installer stops: "not in the wheel group"

Every privileged step runs through sudo, and Void grants sudo to `wheel`. As root, run `usermod -aG wheel <you>`,
log in again, and re-run the installer.

### The install finished with packages in red

A package in the desktop tier failed to install. The closing summary names each one with what it costs (a dead key,
a daemon that never starts). Failures in the extra tier get one yellow line. The run carries on either way. Re-run
`scripts/install-void.sh` once the cause (usually the network or the mirror) is fixed.

### Text files open in nvim, and Sublime Text is missing

Sublime Text comes from Void's nonfree repository. If nonfree could not be enabled, the installer reports it in the
summary and skips the editor, and nvim takes over as the text editor. It is also skipped on musl, where nonfree has
no build. Re-run the installer once the repository is reachable.

### The first login fails with "authentication error"

Older installs started ly's cursor on the user line, so the password you typed went nowhere. ly now starts on the
password field. An existing install picks the fix up from `dots update`, or from `dots theme <name>`.

### The screen freezes right after login (usually in a VM)

picom's `glx` backend stops repainting on a GPU without 3D acceleration. `dwm-picom` now picks `xrender` in any VM
and on any machine without hardware 3D. An `autostart.sh` from before this change has its own picom lines; the
installer tells you to replace them with `dwm-picom &`. `dots doctor` warns when picom runs a different backend
from the one `dwm-picom backend` chooses.

### The bar is empty after logging out and quickly back in

The previous session's `dwmblocks` (and the night-light daemon) outlived X for a moment, so the new session thought
they were running and started neither. The generated `~/.xinitrc` now stops them at logout. An older `~/.xinitrc`
is never edited: the installer prints the block to paste. To get the bar back now:

```sh
pkill -x dwmblocks; setsid -f dwmblocks
```

### The login screen fills with `xsel: Can't open display` after logout

`clipmenud` outlived the session. The generated `~/.xinitrc` stops it at logout. An existing one is told the line to
add or replace on the next install or update.

### After an update, the bar or dwm behaves as before

The running dwm and dwmblocks keep the old build until restarted. `dots doctor` warns about it. Restart them in
place (dwm keeps your windows and tags):

```sh
pkill -HUP -x dwm
pkill -x dwmblocks; setsid -f dwmblocks
```

### `Super` + `a` does nothing

It is read by a small listener, `dwm-shotkey`, started from `autostart.sh`. An `autostart.sh` from before it existed
does not start it, and the installer prints the line to add. `Shift` + `Print` takes the same shot in the meantime.
If it is running but the key still does nothing, `~/.local/state/dots/shotkey.log` says why: it is retrying while
another program holds the keyboard events it listens to, and it picks the key up again once that program is gone.

### `Super` + `a` types an "a" in st

The listener reads `Super` + `a` without grabbing it, so the focused window sees the key too. alacritty's config
(linked from the repo) ignores it at once; st ignores it only once it is rebuilt with the current source. Run
`dots update` (or `scripts/install-suckless.sh`) and open a new st.

### The clock shows a notification instead of a calendar

The calendar needs **python3-gobject**, an optional package. Without it the click shows the month as a
notification, and region screenshots fall back to the older maim and slop selector. Install it:

```sh
sudo xbps-install python3-gobject
```

### An app keeps asking for the keyring password

The keyring's password no longer matches your login password, usually after a `passwd` change. `dots doctor`
reports the keyring as locked. Change the keyring's password in Seahorse, or delete
`~/.local/share/keyrings/login.keyring` and log in again through ly (its stored secrets are lost). Logging in on a
text console and running `startx` never unlocks it. See
[docs/DESKTOP.md § Keyring](https://github.com/YoussefFjel/dots/blob/main/docs/DESKTOP.md#keyring).

### Colours did not change

Check `xrdb -query | grep dwm.`: if it prints nothing, the theme never reached the X resource database. Run
`~/dots/scripts/theme/reload.sh` and read its per-step lines.
[docs/THEMING.md § Troubleshooting](https://github.com/YoussefFjel/dots/blob/main/docs/THEMING.md#troubleshooting)
covers each program that can be left behind.

### The login screen kept its old colours after `Super` + `Shift` + `t`

ly's config is root's, and from a key there is nobody to type a sudo password. The menu leaves ly alone and sends a
notification naming the command. Run `dots login-theme` in a terminal.

### Qt apps open light

A new install needs one logout and login before `QT_QPA_PLATFORMTHEME` reaches the session. `dots doctor` reads it
from dwm's environment, not your terminal's.

### The touchpad does not tap to click

Xorg reads the touchpad file only at start. Log out and back in once after `dots drivers` writes it.

### In a VM: a small screen, a blurry login, a spice-vdagent warning

See [Laptops and Hardware § Virtual machines](Laptops-and-Hardware#virtual-machines). The spice-vdagent warning in
a VM displayed over VNC is expected.

## Still stuck

Check [CHANGELOG.md](https://github.com/YoussefFjel/dots/blob/main/CHANGELOG.md) for a fix that needs a step from
you, then run `dots update`. The pages in
[docs/](https://github.com/YoussefFjel/dots/tree/main/docs) go deeper on each area.
