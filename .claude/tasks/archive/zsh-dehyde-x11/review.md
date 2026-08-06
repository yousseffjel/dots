# Review — zsh-dehyde-x11

## Audit Loop

Tier: **Medium+** (29 files, +386/-753 = 1139 lines).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 found, 1 fixed — `fe` used `${=FZF_DEFAULT_COMMAND}` splitting while `fcd` in the same file used explicit `fd`/`find` branches. Reuse scan dropped HyDE's `ffcd`/`ffch` as duplicates of our `fcd`/`fh`. Verified `install-restore.sh:96` derives manifest CONFIG rows from `symlinks.sh --list-links`, so the starship link reaches `uninstall.sh` with no extra wiring. |
| 2 | Size/Performance | ✅ | 0 found. Max file 205 lines (`symlinks.sh`, cap 250); max function 21 lines (`ex()`, cap 60). Measured: non-interactive 674ms -> 4.6ms, interactive 925ms -> 392ms. |
| 3 | Types/Validation | ✅ | 1 found, 1 fixed (same edit as sweep 1 — the split broke on paths containing spaces). Guards and exit codes verified by execution, not inspection. `shellcheck -x` clean; `zsh -n` clean on all 13 shipped zsh files. |
| 4 | Dependencies | ✅ | 0 found. No `zstyle ':fzf-tab:complete:z:*'` left behind after `z` disappeared under `--cmd cd`. The `.zshenv`<->`.zshrc` mutual-source loop — the original defect — is gone. |

**Audit verdict:** ✅ READY

## Test Gate
**Command:** `tests/lint.sh` + `tests/pkglist.sh` (run on `slot/zsh-dehyde-x11`)
**Result:** ✅ PASSED — shellcheck / shfmt / markdownlint all ok; package lists
valid (format, no duplicates, no core-extra overlap).

**Not run:** `tests/build.sh` — compiles the vendored suckless C tree, which
this diff does not touch, and it needs Fedora build dependencies absent from
this Arch dev host.

**Coverage caveat:** `tests/` holds lint and validation scripts, not behavioural
tests. Nothing in it exercises zsh loading, so the substantive verification for
this task is the manual evidence in `progress.md` (`zsh -n` on all 13 shipped
files, sandboxed interactive shell, real-PTY silence check, before/after
timings).

## Reviewer Gate
**Verdict:** READY
**Notes:** Reviewer was pointed at four specific attack surfaces and cleared all
four: (1) no non-interactive breakage from moving PATH/XDG into `.zshenv`;
(2) no dangling reference to any deleted file or to the now-nonexistent `z`/`zi`;
(3) the `$STARSHIP_CONFIG` indirection is valid given the new `symlinks.sh`
LINKS entry (directories, not files); (4) the "functions/ and completions/ were
never loaded" claim independently re-traced through `terminal.zsh`'s branch
logic to `plugin.zsh`'s `return 1` and the absence of oh-my-zsh — confirmed
rather than taken on trust. No issues raised during the round.
