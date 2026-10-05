# Context — first-boot-fixes

## Background
First end-to-end install on real Fedora (44 Server, libvirt VM, `Virtio 1.0 GPU`, no virgl), 2026-10-05.
Login via ly (tty2) -> ~/.xinitrc (ly config: `xinitrc = ~/.xinitrc`). Observed: bar frozen at `dwm-6.8`
while root WM_NAME held a full dwmblocks status; Super+Shift+Enter mapped a window (border) with invisible
contents. dwm in `poll_schedule_timeout` (not hung). `pkill -x picom` -> everything appeared instantly.
Theme: dwm default colours (#005577/#222222), no ~/.fehbg. Login shell /bin/bash.

## Prior Decisions
- Rule 6: autostart.sh / .xinitrc are user-owned once they exist; never rewritten, only reported.
- User decisions (2026-10-05): probe-at-login for picom; one slot for all three bugs.

## References
- suckless/dwm/dwm.c main(): load xresources -> setup() -> runautostart() (line ~3118); restartsig re-exec re-runs it.
- scripts/theme/reload.sh reload_dwm: `kill -HUP` dwm.
- scripts/install-restore-theme.sh:167 headless skip.

## Notes
- glxinfo lives in Fedora `glx-utils` (subpackage of mesa-demos).
