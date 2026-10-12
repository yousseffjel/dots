# Context — vm-verify

## Background
Scope F slot 4. Slots 1-3 merged (e44d331, 2efa910, d19069f); main at
855d39b, unpushed. User chose: no push, no bundle — getting main onto the VM
is their step; they start the VM themselves (2026-10-12).

## Prior Decisions
- Scope file (main): decisions 1-11; lxpolkit float to verify via `pkexec true`.
- Change logs' Follow-ups: dwm-rules-scratchpad, bar-integration,
  session-integration, xinitrc-clipmenud-cleanup, cursor-theme-x11,
  session-end-orphan-daemons.

## References
- memory fedora-vm-test-box (ssh via ~/.ssh/agent/dots.sock; screenshots via maim)
- KEYBINDINGS.md for every key under test

## Notes
- The session env for scripted checks: read DISPLAY/DBUS_SESSION_BUS_ADDRESS
  from /proc/<dwm pid>/environ, not from the ssh shell.
