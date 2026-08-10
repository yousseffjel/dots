# Review — queue-sweep-1-5

## Audit Loop

Tier: **Medium+** (14 files, +230/-158) -> full 4 sweeps, sequential.

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 2 found / 1 fixed. Fixed: file modes (644 for the sourced-only `install-session-report.sh`, 755 for the new test) — the first fix was wrong and checking all six sourced helpers reversed it. Deferred: three near-identical manifest read-loops; the shared helper belongs in `global_fn.sh`, outside this plan's Scope. |
| 2 | Size/Performance | ✅ | 1 found / 0 fixed — no violation. All files ≤ 250, all functions ≤ 60 (largest: `session_autostart_daemons` 44). `install-restore-theme.sh` is now **248/250**; flagged as the successor queue item rather than trimming load-bearing comments to buy headroom. |
| 3 | Types/Validation | ✅ | 1 found / 1 fixed. SC2016 on the two literal grep patterns in `tmux-tpm-lockstep.sh` — single quotes are required there, so scoped `# shellcheck disable=SC2016` with justification, matching `install-session-report.sh`'s precedent. Re-ran a mutant afterwards to confirm the test was not weakened. |
| 4 | Dependencies | ✅ | 0 found. The new test needs no `tmux` binary (proved on a PATH without it), so CI's bash+coreutils `tests` job will run it. Forbidden paths (`packages/`, `suckless/`, `CURRENT_AUDIT.md`, `MASTER_PLAN.md`) untouched. |

**Audit verdict:** ✅ READY

Full suite: **9/9 green**, including the new `tmux-tpm-lockstep.sh`. dunst held
PID 6788 before and after, so no test killed a live daemon.

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done`
**Source:** repo convention (`TESTING.md:13`) — none of `/test`'s priorities
1–6 match this repo (no `config.yml`, `package.json`, root `Makefile`,
pytest, `go.mod` or `Cargo.toml`), but the suite exists and is documented.
Not a skip.
**Result:** ✅ PASSED — 9/9, 0 failed. dunst held PID 6788 before and after,
so nothing in the suite killed a live daemon.

## Reviewer Gate
**Verdict:** READY

**Notes:** No issues raised. The reviewer verified independently rather than
reading only: it ran `tests/tmux-tpm-lockstep.sh`, `bash -n` and `shellcheck`
over every touched script, and started its own isolated `tmux -f
30-plugins.conf new-session` to confirm `TMUX_PLUGIN_MANAGER_PATH` resolves
through the new `run-shell` indirection with no parse errors. It confirmed by
diff that the `install-session.sh` split is a pure code move with identical
function bodies, and that the CI rewiring is equivalent to what was inlined.
It independently flagged `install-restore-theme.sh` at 248/250 — the same
finding as audit sweep 2, reached separately.
