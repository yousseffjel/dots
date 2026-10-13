# Context — laptop-detect

## Background
scope-h (`.claude/tasks/scope-h-laptop-support.md`), user 2026-10-13: dots
targets desktops AND laptops. DECISION REVERSAL of scope-b decisions 9 + 12.
Slots 1 (detect) + 2 (backlight) merged here: tests/pkglist.sh forbids an
empty .lst and brightnessctl is the first laptop package.

## Prior Decisions
- scope-h 3: laptop packages only on laptops, manifest-tracked.
- scope-h 4: checker in dots drivers + doctor, no new subcommand.
- Rule 10: never name lists in a glob consumer -> `# chassis:` header.
- Decision 12's label rule still holds for gamma ("GAMMA" must not imply backlight).

## References
- brightnessctl -m: "%s,%s,%d,%d%%,%d" (id,class,raw,pct,max); exits 1 "Failed to read any devices of class 'backlight'"
- Fedora brightnessctl.spec: ENABLE_SYSTEMD=1, INSTALL_UDEV_RULES=0 -> logind SetBrightness
- SMBIOS chassis types: 8 Portable, 9 Laptop, 10 Notebook, 14 Sub Notebook, 31 Convertible, 32 Detachable; QEMU default 1 (Other)
- power_supply: type=Battery; peripheral batteries carry scope=Device

## Notes
- Dev host: chassis_type 3, no battery, no backlight. VM: QEMU, only the desktop/unknown path is reachable.
