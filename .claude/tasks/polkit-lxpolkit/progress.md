# Progress — polkit-lxpolkit

## Status
`code complete — audit pending`

## Steps
- [x] 1. `packages/desktop.lst`: `polkit-gnome` → `lxpolkit` + new consequence text.
- [x] 2. `install-session-template.sh`: libexec two-branch block → `command -v lxpolkit` + `pgrep -x` guard; rewrite the why-this-is-special comment.
- [x] 3. `install-session-report.sh`: same replacement on the report side.
- [x] 4. `tests/autostart-daemons.sh`: `DAEMONS` entry; prove a one-sided edit still fails.
- [x] 5. Docs: ROADMAP §3 row + §4.1 list + delete the stale "six of them" count; `HANDOFF.md`.
- [x] 6. Verify: full suite + mutation on the paired-site coupling.

## Deviations
- **Step 2 — the block MOVED between functions, not just edited in place.**
  `session_autostart_services()`'s own header defines its membership: "services
  NOT on PATH, spelled out in full". polkit lived there *because* polkit-gnome's
  binary sat under libexec. `/usr/bin/lxpolkit` is on PATH, so leaving it would
  have made that header false — the prose-disagrees-with-code shape this repo
  keeps rediscovering. It moved into `session_autostart_daemons()` with the
  other `command -v`-guarded daemons. `_daemons` 41 → 54 lines (cap 60),
  `_services` 39 → 19.
- **Step 5 (scope grew slightly)** — two stale cross-references were found and
  fixed because the move invalidated them, both in
  `install-session-template.sh`: the autorandr comment said the polkit agent
  "is spelled out below" (no longer true), and dwm-lock's comment said "the
  three daemons above are system binaries" — a hardcoded count that would have
  become four. The count was **deleted** rather than corrected, per the repo's
  own rule about enumerations.
- Same treatment applied to `ROADMAP.md`'s autostart row, which claimed "six of
  them" when the real number was nine. It now points at the `DAEMONS` array
  instead of restating the list.

## Blockers
_(none)_
