# Plan — install-container-harness

## Goal
CI must run `install-fedora.sh` to completion in a real Fedora container and
assert, so it catches a wrong package name or an aborting stage rather than a
lint error. Today `grep -c install-fedora ci.yml` is 0 — `install-dry-run`
never invokes the installer. `chsh` and `ly.service` must be reported NOT
COVERED, not skipped silently.

## Scope
- `.github/workflows/ci.yml`
- `scripts/install-services.sh`
- `scripts/install-fedora.sh`
- `TESTING.md`
- `CLAUDE.md`
- `docs/UNINSTALL.md`, `ROADMAP.md` (ly unit references only)

## Forbidden
- packages/
- suckless/
- config/

## Steps
1. Guard `systemctl enable ly.service` with the yellow-fallback shape the
   `chsh` call above it already uses; manifest row on success only.
2. Add an `install-container` job on the existing fedora matrix + dnf cache,
   running the installer for real as root.
3. Assert: exit 0, four stages reached, real artifacts (ZDOTDIR, symlinks,
   manifest rows, suckless binaries).
4. Print an explicit NOT-COVERED block naming `chsh` and `ly.service`.
5. Exercise the job body locally under docker before any push.
6. Update `TESTING.md`'s container section and `CLAUDE.md`'s CI paragraph.
7. (added mid-task, approved) Enable `ly@tty2.service`, not the nonexistent
   `ly.service`, and correct `install-fedora.sh`'s closing getty hint.

## Out of scope
- A local `tests/install-container.sh` — decided CI-only this session.
- The graphical session; bumping the `fedora:43` pin.

## Risks
- Slow job (~100 pkgs x 2 legs) — the existing `/var/cache/dnf` cache.
- No green CI baseline exists — mitigated by step 5.
- COPR + zinit/TPM clones need network; failure must stay non-fatal.
