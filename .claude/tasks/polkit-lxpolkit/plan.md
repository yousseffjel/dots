# Plan — polkit-lxpolkit

## Goal
`polkit-gnome` is gone from Fedora (f43 and f44 both), so a fresh install ships
with no PolicyKit agent and CI is red in two jobs. Replace it with `lxpolkit`,
which exists on both targets. Because `lxpolkit` lives at `/usr/bin` — on `PATH`
— the two-branch libexec fallback is deleted rather than re-pointed, making this
an ordinary `command -v` daemon like picom and sxhkd.

## Scope
- `packages/desktop.lst`
- `scripts/install-session-template.sh`
- `scripts/install-session-report.sh`
- `tests/autostart-daemons.sh`
- `ROADMAP.md`
- `HANDOFF.md`

## Allowed
- packages/desktop.lst
- scripts/install-session-template.sh
- scripts/install-session-report.sh
- tests/autostart-daemons.sh
- ROADMAP.md
- HANDOFF.md

## Forbidden
- suckless/
- .github/workflows/
- packages/core.lst
- assets/

## Steps
1. `packages/desktop.lst`: `polkit-gnome` → `lxpolkit`, rewriting the trailing `#` consequence text.
2. `install-session-template.sh`: replace the libexec two-branch block with a `command -v lxpolkit` + `pgrep -x` guard matching the other daemons; rewrite the comment that explains why it was special.
3. `install-session-report.sh`: same replacement on the report side, so existing installs are told the right lines to paste.
4. `tests/autostart-daemons.sh`: `polkit-gnome` → `lxpolkit` in `DAEMONS`; confirm the test fails when only one of steps 2/3 is applied.
5. Docs: ROADMAP §3 auth-agent row + §4.1 package list; `HANDOFF.md`; and delete ROADMAP:313's stale "six of them" daemon enumeration rather than correcting it to nine.
6. Verify: full suite, plus a mutation proving the paired-site test still catches a one-sided edit.

## Out of scope
- Any other queue item; the `xdg-desktop-portal-gtk` and blue-light-filter rows.
- Re-litigating the agent choice — `lxpolkit` is the user's decision (2026-08-13).
- `.claude/changes/**` history, which is immutable.

## Risks
- Package name/path unverifiable locally (no dnf; host is Arch) — mitigated: verified against Fedora's mdapi, `0.5.6-3.fc43` / `0.5.6-4.fc44`, file list shows `/usr/bin/lxpolkit`, and it Provides `PolicyKit-authentication-agent`.
- Rule 6 requires template + report + `DAEMONS` to change together — mitigated: `tests/autostart-daemons.sh` runs both sides and fails on an unpaired edit; step 4 proves that by mutation.
- `pgrep -x lxpolkit` vs the old `pgrep -f polkit-gnome-authentication-agent` — a wrong matcher silently double-launches; mitigated by checking the binary name is what the process is called.
