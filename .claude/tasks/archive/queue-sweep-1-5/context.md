# Context — queue-sweep-1-5

## Background
User selected MASTER_PLAN queue items 1–5 as one clearing pass (2026-08-10).
Items are heterogeneous and touch disjoint files, so they share a slot rather
than being sequenced across five.

## Prior Decisions
- `2026-08-08-polkit-autostart-tiers.md` — deferred the `install-session.sh`
  file split deliberately, naming `install-session-report.sh` as the natural
  sibling and `install-restore.sh`/`install-restore-theme.sh` as the precedent.
- `2026-08-07-thunar-finalization.md` — fixed this same pipefail bug in
  `app_is_ours`; `install-restore-theme.sh` was outside that task's Allowed
  list, which is why it survived. `|| true` is **not** the fix (maps 141 → 0).
- CLAUDE.md rule 6 — `autostart.sh` / `.xinitrc` are user-owned once they
  exist. Step 1 must not change that guarantee.
- CLAUDE.md rule 3 — every script derives `SCRIPT_DIR` from `BASH_SOURCE`.

## References
- `scripts/install-session.sh:26-86` — the two functions to move (68 lines).
- `scripts/install-restore-theme.sh:26,36` — the two SIGPIPE pipelines.
- `scripts/install-restore-apps.sh:35-41` — `app_is_ours`, the read-loop shape
  to copy verbatim.
- `scripts/theme/reload.sh:78-85` — `run_bounded`, the `timeout 10` precedent.
- `config/theme/templates/always/xresources.dcol:1` — the unbounded header.
- `config/tmux/conf.d/30-plugins.conf:4,33,34,38` — four hardcoded paths.
- `.github/workflows/ci.yml:27-46,111-136` — the inline copies of lint/build.

## Notes
- **tmux is not a shell.** Context7 (`/tmux/tmux`, Getting-Started) confirms
  tmux.conf expands `$VAR`/`${VAR}` but "does not support shell-specific
  constructs" — so `${XDG_DATA_HOME:-$HOME/.local/share}` works only inside a
  **single-quoted** `run-shell`/`if-shell` body, where sh does the expansion.
  Line 38 already relies on exactly that. `set-environment` (line 4) has no
  shell, so it needs a `run-shell` wrapper to get the default.
- `config/zsh/.zshenv:17` exports `XDG_DATA_HOME` with the same default, so a
  tmux started from a login zsh always has it set; the `:-` covers the rest.
- `tests/lint.sh` skips missing tools by design (local use). Wired into CI
  as-is, a failed tool install would produce a green job that checked nothing.
- CI installs shfmt via `go install` — its `GOPATH/bin` must reach `$PATH`
  before `tests/lint.sh`'s `command -v shfmt` can see it.
- Post-commands run through `bash -c` in `apply-templates.sh:182`, after
  `expand_path` substitutes `${cacheDir}` — so a shell `if/then/else` string is
  valid in a `.dcol` header.
