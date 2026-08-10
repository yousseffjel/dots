# Plan — queue-sweep-1-5

## Goal
Clear MASTER_PLAN queue items 1–5 in one pass: unblock the 250-line cap on
`install-session.sh`, stop CI from reimplementing two test scripts it never
runs, and fix three shipped-code defects (pipefail SIGPIPE, an unbounded
`xrdb`, and a TPM path that ignores `$XDG_DATA_HOME`). Item 6 (real hardware)
is out of scope — it needs a Fedora box, not a code change.

## Scope
- `scripts/install-session*.sh`
- `scripts/install-restore*.sh`
- `.github/workflows/ci.yml`
- `tests/lint.sh`
- `config/theme/templates/always/xresources.dcol`
- `config/tmux/conf.d/30-plugins.conf`
- `HANDOFF.md`, `TESTING.md`, `CLAUDE.md`

## Forbidden
- `packages/`
- `suckless/`
- `.claude/changes/CURRENT_AUDIT.md`
- `.claude/tasks/MASTER_PLAN.md`

## Steps
1. Split `session_report_daemon` + `session_autostart_report` out of
   `install-session.sh` into `install-session-report.sh`; the parent sources it
   by its own `BASH_SOURCE` dir so `tests/autostart-daemons.sh` still works.
2. Add `--strict` to `tests/lint.sh` (missing tool = failure, not skip); have
   the CI `lint` job call it and `build-suckless` call `tests/build.sh`.
3. Replace both `cut | grep -qxF` pipelines in `install-restore-theme.sh` with
   the read-loop shape already used by `app_is_ours`.
4. Bound `xresources.dcol`'s `xrdb -merge` post-command with `timeout 10`,
   degrading to unbounded when `timeout` is absent (matches `run_bounded`).
5. Honour `$XDG_DATA_HOME` for TPM in `install-restore.sh` **and** all four
   hardcoded sites in `config/tmux/conf.d/30-plugins.conf`.
6. Update `HANDOFF.md`, `TESTING.md` and `CLAUDE.md` for the new file, the new
   flag, and the tmux/installer lockstep.

## Out of scope
- Queue item 6 — running `install-fedora.sh` on real hardware.
- Wiring a 7th daemon; step 1 only makes room for one.
- The uncommitted `yt-dlp` aliases in `config/zsh/conf.d/60-aliases.zsh`.

## Risks
- Step 1 breaks `tests/autostart-daemons.sh` — it sources the file; run it.
- Step 2 could go green having checked nothing — `--strict` is the mitigation.
- Step 5 desyncs installer and tmux — both sides change together, one commit.
