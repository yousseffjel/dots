# Context — live-interrupt

## Background
MASTER_PLAN Queue item "Live install: an interrupt does not stop the inner install-void.sh" (J-4 follow-up). User 2026-10-19: fix the live installer AND a direct install-void.sh run ("Live + direct run").

## Prior Decisions
- J-2: the temporary NOPASSWD rule is armed with an EXIT trap; INT/TERM become exits (install-live.sh:186-190).
- J-2: live_dots_release stops processes by /proc/<pid>/root == target, never by user (uid 1000 can be the ISO's own user); LIVE_PROC overrides /proc in tests.

## References
- scripts/install-live.sh:186-191 (traps), scripts/install-live-dots.sh (grant/release/revoke/install)
- scripts/install-pkg-tiers.sh:172-189 (batch fails -> "retrying one package at a time" via tier_settle)
- scripts/install-void.sh:77-81 (exec > >(tee …), EXIT trap)
- tests/live-dots.sh (the only test touching release/revoke)
- Evidence: J-4 run (transcript 2a5f0147): after `timeout -s INT 150`, "FAILED: Thunar … xbps: sudo: a password is required" and "install-pkg-tiers.sh: line 135: /dev/fd/63: No such file or directory" — install-void.sh kept going after install-live.sh and xchroot (which unmounted /dev) had exited.

## Notes
- GNU timeout (no --foreground) signals its whole process group; a terminal Ctrl-C signals the foreground group. util-linux `su -c` may run the command in a new session, so the inner install may never see the SIGINT: the outer side must kill by /proc root.
- Bash runs an INT trap only after the current foreground child returns.
