# Progress — hardware-drivers

## Status
`in-progress`

## Steps
- [x] 1. drivers-detect.sh sysfs readers
- [x] 2. drivers-gpu.sh
- [x] 3. drivers-firmware.sh
- [x] 4. drivers.sh CLI + dispatcher + installer hook
- [x] 5. doctor-drivers.sh
- [x] 6. tests
- [x] 7. docs + VM run

## Deviations
- Step 6: fixture sysfs trees are generated inside tests/drivers.sh (`gpu` helper)
  rather than committed under tests/fixtures/sysfs/ — a dozen one-line files per
  case, and CLAUDE.md reserves tests/fixtures/ for captured real-tool output.
  Cases split into tests/lib/drivers-cases.sh (250-line cap; tests/lib is outside
  the runner's glob).
- Step 7: README.md (command list) also touched — not in plan Scope.
- Bug found in step 6: drivers-detect.sh resolved DOTS_SYSFS at source time, so a
  test setting it afterwards read the REAL /sys. Now read at call time.
- install-pkg-repos.sh sources drivers-lib.sh by its own dirname, not the
  caller's SCRIPT_DIR (tests/pkg-repos.sh sources it from tests/).
- Step 7 (VM, f44 kvm/virtio): found that an unreadable kernel log (sudo refused)
  was reported as "no failed firmware loads". Now says "firmware not checked";
  tests/drivers.sh case added.

## Blockers
