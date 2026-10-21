# Context — uninstall-dryrun-preview

## Background
Void VM edge-case loop (user: "keep testing and fixing"). `uninstall.sh
--dry-run </dev/null` on the VM: rc=0, 136 lines, every category "skipped".

## Prior Decisions
- uninstall_state already never prompts under --dry-run (precedent).
- docs/UNINSTALL.md: `dots uninstall --dry-run   # preview every action`.

## References
- tests/install-uninstall-symmetry.sh, tests/lib/install-symmetry.sh

## Notes
- confirm() has no caller outside scripts/uninstall*.sh.
