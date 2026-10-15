# void-port-scope — open scope I: port dots from Fedora Server to Void glibc

## What changed
- New branch `void` (worktree `.claude/worktrees/void/`), branched from `e89cd01`.
- `.claude/tasks/scope-i-void-port.md`: research findings, package map,
  systemd → runit/elogind table, locked decisions D1–D3, sub-tasks I-1..I-10.
- No code changed.

## Why
User decision: rebuild the project around Void Linux instead of Fedora.

## Key Technical Decisions
- **DECISION REVERSAL:** "Fedora only" and "Fedora Server is the one supported
  target" (2026-10-14) are superseded on this branch. Target is Void glibc
  x86_64. `main` stays Fedora until the branch merges.
- D1 build ly from source (runit service), D2 elogind, D3 vendor Cascadia
  Code NF under `assets/fonts/` (user choices, 2026-10-15).
- A separate worktree, not a branch switch in the main checkout, because the
  live `~/.config` symlinks point into the main checkout.

## Assumptions Made
- (B) `NetworkManager` ships `nmtui`, and `noto-fonts-ttf` covers Arabic and
  the Noto faces the Fedora lists named one by one. Both still need checking
  in I-2.
- (B) `power-profiles-daemon` exposes the same D-Bus API `dwm-power` uses with
  tuned-ppd.

## Test coverage
- Package names: all 128 `packages/*.lst` entries checked against Void's
  official x86_64 repodata (main + nonfree, 14,890 packages, fetched
  2026-10-15): 102 exact, 26 mapped or flagged in the scope file.
- Sources: Void Handbook via Context7 (`/websites/voidlinux`),
  docs.voidlinux.org session-management page, the fairyglade/ly README, and
  voidlinux.org's 2023 container announcement.

## Follow-ups
- I-5 must answer the zig snag: ly needs zig 0.17.x, but Void ships 0.13.0.
- Start I-1 (docs, identity, installer rename) as the first slot.
