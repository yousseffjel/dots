# Context — vm-picom

## Background
User 2026-10-14: add VM to the PC/laptop checker; make picom pick its backend from the hardware. Picom already probed GL in autostart.sh (2026-10-05 first-boot fix); gaps: probe frozen in user-owned autostart.sh; a VM with 3D (virgl) gets glx.

## Prior Decisions
- User 2026-10-14: `vm` chassis result; dwm-picom script + "VM -> xrender".
- Rule 6: autostart.sh user-owned; report tells existing installs what to paste; tests/autostart-daemons.sh runs both sides.
- 2026-10-05: picom glx froze the VM screen (virtio, no 3D).

## References
- scripts/install-session-template.sh session_autostart_compositor; install-session-report.sh session_report_picom_probe; doctor-session.sh picom-backend; tests/picom-backend-probe.sh.
- systemd-detect-virt --vm: VMs only (containers excluded), rc 0 + name.

## Notes
- config/dwm/bin is on PATH for the session (zshenv); autostart already runs dwm-lock/dwm-nightlight from it.
