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
