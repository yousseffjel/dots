# Context — ly-rebuild

Queue item (MASTER_PLAN): ly_install returns "already built" whenever a
LYBUILD /usr/bin/ly row exists. Log 2026-10-19-live-docs.md.
Uninstall: uninstall_ly_build removes LYBUILD col-3 paths; the whole state
dir goes at the end of dots uninstall, so META ly_build needs no revert.
