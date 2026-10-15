# dunst-keep-state — theme apply keeps focus mode and the notification history

Date: 2026-10-15
Files: 13 | Lines: +247/-25

## What changed
- `scripts/theme/reload-dunst.sh` (new, sourced, 644): `reload_dunst` —
  not installed / not running → skip; otherwise read `dunstctl
  get-pause-level`, `dunstctl reload`, put a level > 0 back with
  `set-pause-level`; a failed restore is a red line; a failed reload falls
  back to the old `pkill -x dunst`.
- `scripts/theme/reload.sh`: sources it (the function pushed the file to 259
  lines); gained the rule-3 `SCRIPT_DIR` line it never had.
- `config/theme/templates/always/dunst.dcol`: post-command `pkill -x dunst` →
  `true` (reload.sh is the one owner); header rewritten; new `[dots_osd]`
  rule (`appname = dwm-osd`, `history_ignore = yes`).
- `config/dunst/dunstrc`: the same `[dots_osd]` block, identical.
- `tests/dunst-reload.sh` (new): real reload.sh on a sealed PATH of fakes
  (11 checks), config lockstep (3), and a real-dunst private-bus run.
- Stale comments in `tests/{fastfetch-template,starship-template,picom-lockstep}.sh`;
  `docs/THEMING.md` diagram + table; KEYBINDINGS.md note; CHANGELOG [Unreleased] Fixed.

## Why
The user's VM screenshots after notify-center: the list was empty right after
`dots update`, and the bar said FOCUS while the centre offered "Turn on focus
mode" with a `dwm-osd: Volume` entry in history. The theming engine killed
dunst on every theme apply (every wallpaper change); D-Bus then started a
fresh dunst — empty history, unpaused. OSD pop-ups are dunst notifications, so
they filled the history.

## Key Technical Decisions
- Reload, not restart. Probed on a private bus (dunst 1.13.2): `dunstctl
  reload` keeps the pid and the history and applies new colours (popup pixel
  changed), but resets the pause level to 0 — hence save/restore.
- One owner: the dcol post-command did the same kill as reload.sh, and both
  callers (theme-apply.sh, wallpaper.sh) always run reload.sh after
  apply-templates.sh.
- `history_ignore` only applies when the OSD expires (a `close-all` while it is
  on screen still files it); dwm-osd's pop-ups expire after 1.5 s, so the test
  lets it expire rather than closing it.

## Assumptions Made
- (B) Root cause inferred from the `dots update` log + probes, not confirmed in
  the VM's journal (ssh agent was gone).

## Test coverage
- `tests/dunst-reload.sh`: all pass, including real dunst under
  `env -u WAYLAND_DISPLAY dbus-run-session` + Xvfb: history 2 (OSD excluded),
  2 after reload, pause level 2 kept, same process, nothing killed.
- Mutations (scratch copies): 8 caught — no restore, kill instead of reload,
  restore when unpaused, no running check, dcol kills again, OSD rule missing
  in the static dunstrc, restore removed from the moved file, source line removed.
- `tests/run-tests.sh` 74 OK, 1 SKIP (dwm-runtime, no dwm binary in the
  worktree); `tests/lint.sh --strict` passes. Reviewer READY.
- **Not verified:** on the VM.

## Follow-ups
- Verify on the VM: turn focus on, `Super+w`, focus still on and the list kept;
  volume key → nothing new in the list.
