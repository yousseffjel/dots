# 2026-08-04 — Verify + fix package names in Fedora/Arch install scripts

## Scope

- `scripts/install-arch.sh` (1-line fix)
- `scripts/install-fedora.sh` (package list + header/footer notes)
- `scripts/install-fedora-server.sh` (verified, no changes needed)

## What changed

User asked for a correctness pass over the two install scripts from the
prior session (`2026-08-04-fedora-server-arch-install-scripts.md`) — this
was independent re-verification, not a continuation of that session's own
self-check.

Verified every package name against live sources rather than re-trusting
the prior session's web research:

- **Arch**: this machine runs Arch, so every package in `install-arch.sh`
  (~70 names, `PACKAGES` + `REQUIRED`) was checked directly with
  `pacman -Si <pkg>`. One miss: `p7zip`. Arch replaced it with `7zip` in
  2024 (`pacman -Si p7zip` now resolves only via `chaotic-aur`; `pacman -Si
  7zip` resolves in `extra`). Fixed in place.
- **Fedora**: no Fedora machine available, so a subagent verified every
  package in `install-fedora.sh` and `install-fedora-server.sh` (~60 names
  combined) against packages.fedoraproject.org. Two misses, both in
  `install-fedora.sh`'s desktop `PACKAGES` array: `lazygit` and
  `bibata-cursor-themes` are not in official Fedora repos — COPR only
  (`dejan/lazygit` and `peterwu/rendezvous` respectively). Everything else
  confirmed correct, including several names I flagged as suspicious going
  in (`ly`, `eza`, `opendoas`, and `xrandr`/`xsetroot`/`xset`/`xrdb`/
  `xinput` as standalone dnf packages all genuinely exist as named).

`scripts/install-fedora.sh`: dropped `lazygit` and `bibata-cursor-themes`
from the best-effort `PACKAGES` array, added a header-comment note with the
`dnf copr enable` commands for both, and a closing yellow reminder line —
mirroring the exact pattern `install-arch.sh` already uses for its own
AUR-only package (`bibata-cursor-theme`, dropped with a closing reminder
in the prior session).

`scripts/install-arch.sh`: `p7zip` -> `7zip` in the `PACKAGES` array.

## Key technical decisions

- Matched the fix pattern to the one already established in
  `install-arch.sh` for `bibata-cursor-theme` (drop from the best-effort
  loop, document the manual COPR/AUR path in the header + closing message)
  rather than inventing a new convention for Fedora's `lazygit`/
  `bibata-cursor-themes`. Consistency across the two sibling scripts.
- Did not bootstrap a COPR-enable step automatically — same trust-boundary
  reasoning the prior session applied to AUR helpers: enabling a
  third-party repo is a separate decision from installing official
  packages, left to the user.

## Assumptions made

- Type C — Fedora package verification is web-based (no Fedora machine
  available this session either), same caveat as the prior session. The
  best-effort per-package loop remains the safety net for any further
  drift.

## Verification

`bash -n` on both edited scripts. Full live `pacman -Si` check against
every package in `install-arch.sh` on this machine (Arch). Fedora package
list verified by a research subagent against packages.fedoraproject.org.
Independent `reviewer` subagent pass: confirmed both fixes are correctly
applied and internally consistent — `READY`.

## Trade-offs

- `lazygit` and `bibata-cursor-themes` no longer install automatically on
  Fedora desktop bootstrap — down from "attempted, silently skipped" to
  "documented as a manual step." Functionally the script's end state is
  unchanged (neither ever actually installed via dnf), but the intent is
  now honest about it rather than listing an unreachable package name.

## Next steps

None outstanding — both scripts and the server variant are now verified
package-name-correct as of 2026-08-04. Still not run end-to-end on real
Fedora/Arch hardware (carried over from the prior session's Next Steps).
