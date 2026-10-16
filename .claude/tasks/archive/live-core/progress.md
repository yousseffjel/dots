# Progress — live-core

## Status
`in-progress`

## Steps
- [x] 1. Research on the VM's live ISO; record in context.md
- [x] 2. install-live-answers.sh + tests/live-answers.sh
- [x] 3. install-live-base.sh (preflight + bootstrap)
- [x] 4. install-live-config.sh (chroot config + GRUB)
- [x] 5. install-live.sh orchestrator + tests/live-dry-run.sh
- [x] 6. VM run, UEFI and BIOS
- [x] 7. CLAUDE.md + CHANGELOG

## Deviations
- Step 1 was researched from sources (void-mklive, repodata, the xtools-minimal .xbps), not on a booted ISO. Booting the ISO is step 6, which confirms the findings.
- Step 2 split the validators into `install-live-validate.sh` from the start (still within `scripts/install-live*.sh`), keeping each file well under the 250-line cap.

- Step 3: the live package names go in `packages/live/base.lst` + `uefi.lst` (user's choice, 2026-10-16, over an inline array or a top-level list with a marker). `dots doctor`'s depth-1 glob never sees them, and `tests/void-pkgnames.sh` + `tests/pkglist.sh` were extended to glob `packages/live/*.lst`. Scope widened by these 3 paths, plus `.github/workflows/ci.yml`'s package-names step (the live-index twin of void-pkgnames.sh, the same one-glob change; without it the live lists would be checked only against the snapshot). The 4th risk (size caps) was dropped from plan.md to keep it at 40 lines; the caps are still checked in the audit.

- Step 6 found one bug and one cosmetic issue, both fixed in this slot:
  (1) **plain `chpasswd` exits 0 and sets nothing in the Void target**, so
  the dialog path left the user with no password and reported success. Now
  it uses `chpasswd -c SHA512`, and `live_check_password` reads
  /etc/shadow back (tested in live-dry-run.sh). (2) A dry run printed
  "ok … installed": the closing lines now use `live_ok`.

## Blockers
