# Context — wallpaper-follows-display

## Background
VM 2026-10-05: user set 1920x1080 by hand with xrandr; generated wallpaper filled only the 1280x800 corner.
User wants a fixed 1920x1080 -> `autorandr --save vm` on the VM (per-machine, not a repo change); autostart's
`autorandr --change` applies it at login, after .xinitrc already painted the wallpaper -> this task.

## Prior Decisions
- Rule 7: symlinks.sh links dirs; files a program writes into must be copied (dunst/picom/thunar precedent).
- visual-defaults: ~/.fehbg may be the user's own wallpaper — the hook only re-runs it, never rewrites it.

## References
- autorandr README: hooks in ~/.config/autorandr/<hook>.d/, executable, run in filename order;
  global hooks also under /etc/xdg/autorandr.
- scripts/install-restore-apps.sh deploy_app_file (copy + APP manifest row; uninstall-apps removes).
