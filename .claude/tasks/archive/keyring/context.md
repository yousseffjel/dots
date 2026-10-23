# Context — keyring

## Background
Scope K (`.claude/tasks/scope-k-integrated-desktop.md`, main), locked decision 1:
gnome-keyring 48.0, unlocked by PAM at the ly login, secrets component only.

## Prior Decisions
- Scope F: dwm never reads /etc/xdg/autostart; autostart.sh starts applets itself.
- Lesson from the portal work: doctor checks the effect, not the config (doctor-portal.sh header).

## References
- ly v1.4.1 @ afb1dc6 `res/pam.d/ly-linux`: `-auth optional pam_gnome_keyring.so`,
  `-password optional pam_gnome_keyring.so use_authtok`, `-session optional pam_gnome_keyring.so auto_start`
  (after `-session optional pam_elogind.so`, so XDG_RUNTIME_DIR exists). build.zig installs it as /etc/pam.d/ly.
- gnome-keyring-48.0_1.x86_64.xbps: /usr/lib/security/pam_gnome_keyring.so,
  /usr/share/dbus-1/services/org.freedesktop.secrets.service
  (Exec=gnome-keyring-daemon --start --foreground --components=secrets),
  /usr/share/xdg-desktop-portal/portals/gnome-keyring.portal,
  autostart entries OnlyShowIn=GNOME;Unity;MATE;.

## Notes
- ~/.xinitrc already hands DISPLAY to D-Bus activation (unlock prompts can draw).
