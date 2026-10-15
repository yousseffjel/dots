# void-i10-real-run — I-10: the installer on a real Void VM

## What was run
- **The VM:** a fresh Void glibc x86_64 VM (libvirt, QXL, kernel 6.18.56).
  The user cloned `-b void` and ran `scripts/install-void.sh`. ssh was at
  192.168.122.243, then .242 once NetworkManager took over from dhcpcd and
  got a new lease.
- **Verified over ssh**, with the session's environment read from
  `/proc/<dwm>/environ`:
  - the login chain: runsv ly → ly → .xinitrc → dbus-run-session → dwm;
  - the elogind session is active on seat0/tty2;
  - pipewire, wireplumber and pipewire-pulse are running ("PulseAudio (on
    PipeWire 1.6.9)");
  - the portal returns dark mode;
  - dbus, elogind, NetworkManager, bluetoothd and spice-vdagentd are running;
  - agetty-tty2 is down;
  - the UPD block reads 0;
  - install.log has no warnings.
- **Verified by the user in the desktop:**
  - `busctl ... CanPowerOff` returns "yes" (ssh gets "challenge", as a
    non-active session should);
  - `dots doctor` reports "all checks passed" after a re-login.

## Found and fixed
- **The VOL block showed 40% while pamixer said 100** (a port regression).
  Fixed by `dwm-audiowatch`, in its own log:
  2026-10-15-void-audiowatch.md (5d1b8b1).
  - Verified live: a `pactl` volume change with no key pressed reached the
    bar within a second, and a second launch exited.
  - Verified across a re-login: doctor reports it running, and the bar
    matches pamixer.

## VM settings, not repo bugs (documented in docs/HARDWARE.md)
- **The X session started at 1024x768.** It is now 1920x1080, saved as the
  autorandr profile `vm-1080p`, which survived the re-login.
- **The ly pointer was huge and covered the login box.** The kernel console
  stayed at 1024x768 and the viewer stretched it, and the QXL pointer is
  frozen at the greeter (no agent runs there). Fixed by
  `video=Virtual-1:1920x1080` in GRUB_CMDLINE_LINUX_DEFAULT; the user
  confirmed it worked.
- **The status text was wider than a 1024 px bar**, so its left end was cut
  off. This went away at 1920x1080.

## Assumptions Made
- (B) The console resolution belongs in docs, not the installer. A kernel
  `video=` mode is machine-specific; on bare metal the console already runs
  at the panel's native mode.

## Not covered
- Bare metal; suspend/resume; a laptop. Suspend was optional and not run.

## Follow-ups
- Merging `void` into main is the user's decision.
