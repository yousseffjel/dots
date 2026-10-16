# Context — live-dots

## Background
Scope J sub-task J-2 (`.claude/tasks/scope-j-live-install.md`). J-1 (`0bec1f5`)
leaves a bootable tty system and tells the user to clone + install by hand.

## Prior Decisions
- Scope J locked decisions 1-10; J-2 row: temporary NOPASSWD removed by a trap.
- Plain chpasswd no-ops in a Void chroot (J-1) — read state back, don't trust exit codes.
- Rule 1 (re-runnable), rule 10 (no inline package names), 250/60 caps.

## References
- scripts/install-live.sh:121-133 (stage order, closing text)
- scripts/install-live-config.sh:22 live_in_target, :29 live_write, :119-133 sudoers pattern
- scripts/install-services.sh:100,135 `${USER:-…}` — the root-leak site
- scripts/install-restore-flatpak.sh:72-90, install-restore-apps.sh:131-197 (bus-dependent)
- scripts/install-void.sh:77-78 tees install.log into the clone (must be user-writable)
- .github/workflows/install-container.yml:89-101 proves the root path only
- .claude/tasks/archive/live-core/context.md:44 xchroot binds resolv.conf

## Notes
- doctor fails only on: missing manifest, SERVICE rows missing from /var/service, packages.
- No fc-cache / xdg-user-dirs-update at install time; theme waits for first login (no DISPLAY).
- Type B assumptions: clone path `~/dots`; clone from the live clone (no 2nd network fetch,
  same commit); extra dbus-run-session restore pass; reboot automatic only with `--reboot`.
