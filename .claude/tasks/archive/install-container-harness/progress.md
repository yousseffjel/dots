# Progress — install-container-harness

## Status
`in-progress`

## Steps
- [x] 1. Guard `systemctl enable ly.service` with the `chsh`-style yellow
      fallback; manifest row on the success branch only.
- [ ] 2. Add the `install-container` job on the existing fedora matrix + dnf
      cache, running the installer for real as root.
- [ ] 3. Assert: exit 0, four stages reached, real artifacts (ZDOTDIR,
      symlinks, manifest rows, suckless binaries).
- [ ] 4. Print an explicit NOT-COVERED block naming `chsh` and `ly.service`.
- [x] 5. Exercise the job body locally under docker before any push.
- [x] 6. Update `TESTING.md`'s container section and `CLAUDE.md`'s CI
      paragraph.

## Deviations

- **Step 1 does not suppress stderr**, unlike the `chsh` call it mirrors.
  systemctl's own message ("System has not been booted with systemd as init
  system (PID 1)", "Unit file ly.service does not exist") is the useful half of
  the failure branch; `chsh`'s is predictable PAM noise. Deliberate, commented
  at the site.
- **No `tests/install-services.sh` was added for step 1.** The
  `install-container` job covers the regression directly — a revert to the bare
  call aborts the services stage and reddens the job. A dedicated test would
  restate the same fact in a second place, which this repo has repeatedly found
  to be a drift site.

- **Step 1 grew a second fix, in scope but unplanned.** The first container run
  aborted the services stage at `install-services.sh:62` with
  `USER: unbound variable` — `$USER` is unset in a container and `set -u` makes
  that fatal. Fixed via `id -un` plus a `|| true` on the getent pipeline (with
  `pipefail`, a passwd miss aborts on the assignment itself, silently). Same
  file, already in `## Scope`.
- **The NOT-COVERED block was wrong on its first draft and was rewritten from
  evidence.** It claimed `chsh` could not work in a container; the run printed
  "Shell changed" and `getent` confirmed it. Corrected in both `ci.yml` and
  `TESTING.md` — what is genuinely unproven is that a *login* then starts zsh.
- **Timeout set from measurement, not guess:** 45 → 90 min. A cold
  `fedora:latest` run took **32 minutes** locally, on fast CPU and network,
  because `install-pkg.sh` runs one dnf transaction per package.

## Blockers

Two bugs found BY the harness, both outside this task's `## Forbidden`, both
needing a decision before they can be fixed:

1. **`polkit-gnome` is retired on Fedora 44** — `dnf list --available` does not
   resolve it, so `install-dry-run` goes red on it too, independently of this
   task. `packages/` is Forbidden here. Available replacements: `lxpolkit`,
   `mate-polkit`, `xfce-polkit`, `polkit-kde`. Swapping one in is a
   three-file change (`desktop.lst` + the absolute libexec path in
   `install-session-template.sh` and `install-session-report.sh`).
2. **`ly.service` does not exist.** The Fedora package ships a *templated*
   `ly@.service` (`Conflicts=getty@%i.service`, no `Alias=`), so
   `systemctl enable ly.service` has never worked — the display manager has
   never actually been enabled by this installer on any machine. Correct form
   is `systemctl enable ly@tty2.service`, which requires choosing a TTY.
