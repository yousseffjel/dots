# Progress — keyring

## Status
`done (step 6 deferred)`

## Steps
- [x] 1. desktop.lst: `gnome-keyring` with its consequence comment (rule 10)
- [x] 2. portals.conf: `org.freedesktop.impl.portal.Secret=gnome-keyring`, header reworded
- [x] 3. scripts/doctor-keyring.sh: check_keyring + doctor.sh wiring
- [x] 4. tests/doctor-keyring.sh: fake gdbus on PATH, every report branch
- [x] 5. Docs + CHANGELOG [Unreleased]
- [ ] 6. Void VM: ly login, secret store/lookup with no prompt; doctor ok — NOT RUN (ssh agent gone; Follow-ups in the log)

## Deviations
- Step 4: the fake keyring replies went into the SHARED `tests/lib/doctor-sandbox.sh`
  gdbus fake (dispatch on `--dest org.freedesktop.secrets`), so tests/doctor.sh's
  healthy run asks it too. tests/doctor.sh itself is untouched (244 lines, cap).
- Step 4: added a real-binary leg (gnome-keyring 51.1 on a private bus, PAM-style
  `--login` + activation) — it also proved the attach mechanism on the host.
- Step 5: two out-of-Scope edits — CLAUDE.md (doctor module list; the docs/ line
  replaced by "`ls docs/` is the list", it had already missed LIVE-INSTALL.md) and
  docs/DESKTOP.md is NEW (one doc for all of scope K; later slots add sections).

## Blockers
