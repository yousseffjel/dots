# hyde-parity
Date: 2026-08-13
Files: 39 | Lines: +1954/-69
(of which the two features are 33 files, +1761/-66 — the rest is this log and
the task folder. One file is binary: a 1.7 MB vendored tarball.)

## What changed

Two items from `MASTER_PLAN.md`'s "Framework parity with HyDE" block, taken in
one slot.

**1. `scripts/dots` — one user-facing command on `$PATH`.** HyDE has `hydectl`;
this repo had 21 scripts under `scripts/`, none of them on `$PATH`. `dots`
dispatches to the four user-facing entry points (`theme-apply.sh`,
`wallpaper.sh`, `version.sh`, `uninstall.sh`), forwarding arguments verbatim —
`dots theme --list` *is* `scripts/theme/theme-apply.sh --list`. Nothing moved
and every script stays independently runnable.

- **Its `SUBCOMMANDS` table is the only declaration of the subcommand list.**
  `--help` renders from it, `config/zsh/completions/_dots` parses that `--help`,
  and `tests/dots-dispatch.sh` reads it back and *runs* each entry. Adding a
  subcommand is one line; nothing else can go stale.
- **It deliberately breaks rule 3.** Reached through a symlink, the repo's usual
  `cd "$(dirname "${BASH_SOURCE[0]}")"` resolves `~/.local/bin` — `cd` follows
  the directory, never the file — so every subcommand would look for the repo in
  the wrong place. It uses `readlink -f`. Documented in situ, in `CLAUDE.md`, and
  proved by a test that invokes it through a real symlink.
- **`DOTS_CMD`** lets each target print how it was actually invoked
  (`usage: dots version [--json]`, not `usage: version.sh`) while direct
  invocation is unchanged.
- New `config/zsh/completions/` (the directory did not exist), with `fpath`
  wired in `conf.d/30-zinit.zsh` **before** `compinit` — an addition after it is
  a no-op.

**2. The Bibata cursor theme, vendored.** `assets/cursors/` holds the upstream
`v2.0.7` release tarball, its `.sha256`, and the GPL-3.0 text;
`scripts/install-restore-cursor.sh` extracts it into `~/.local/share/icons` and
claims it as a `THEME` row so `uninstall.sh` removes the tree. All four
`themes/*/theme.conf` now name it.

- **The theme name is read out of the archive**, never hardcoded, and
  `tests/cursor-theme.sh` checks it against every `theme.conf` with the shipped
  `theme_conf_get`. This coupling is silent when broken — GTK just falls back to
  a default cursor, no error anywhere.
- The artifact is verified against its checksum before extraction.

**Supporting:** `SCRIPT` manifest row + a generalised `uninstall_scripts`
(its prompt said "dwmblocks block script(s)" and would have lied the moment a
second kind of row appeared); `xz` declared in `desktop.lst`; docs reconciled
across `README`, `THEMING`, `UNINSTALL`, `KEYBINDINGS`, `TESTING`, `ROADMAP`,
`CREDITS` and `CLAUDE.md`.

## Why

Both were queue items whose framing turned out to be wrong once the code was
read rather than the entry:

- **The item said "font *and* cursor assets".** Fonts were already fully
  packaged — `cascadia-code-nf-fonts` in `desktop.lst` (with consequence text)
  plus the noto set in `extra.lst`, and `extra.lst` even records why the obvious
  JetBrains Nerd variant was rejected. Only cursors were missing. Half the item
  did not exist.
- **The item said vendoring meant "downloading from GitHub releases at install
  time is a trust decision".** HyDE does not download:
  `HyDE/Scripts/restore_fnt.sh:47` extracts tarballs already in the clone. The
  reference implementation was the fourth option the entry never considered, and
  it is the one taken here — no network at install time, artifact pinned.

## Assumptions

- **Type B — vendoring over COPR.** Chosen by the user from four presented
  options. Consequence accepted going in: this is the first binary blob in a
  repo that had only ever vendored `.diff` files and C sources, ~18x the largest
  previously tracked file, and **nothing watches it** — the same blind spot the
  23 suckless `.diff` files have. `assets/cursors/README.md` says so and gives
  the manual bump procedure.
- **Type B — the repo now redistributes GPL-3.0 material.** `themes/CREDITS.md`
  records a deliberate decision to reimplement rather than vendor HyDE's code
  *because* of GPL obligations, so this is a change in posture even though it is
  aggregation, not derivation: no Bibata code is linked into or built against
  anything here. The licence ships beside the artifact, exactly as
  `suckless/*/LICENSE` does. Recorded in `CREDITS.md`.
- **Type B — `Bibata-Modern-Classic`** (black, rounded) over Ice/Original,
  chosen by the user. It survives a future light-mode decision, which Ice
  would not.
- **Type C — two new sourced helper files** (`install-restore-bin.sh`,
  `install-restore-cursor.sh`) rather than inline blocks, following the existing
  `install-restore-theme.sh` → `restore_theme` pattern. Inline blocks in
  `install-restore.sh` are unreachable by a test without re-running the stage.
- **Type C — `MASTER_PLAN.md` untouched.** It is main-side
  (`session-protocol.md`); striking the two parity bullets is a post-merge step.

## Test coverage

**`/test` was invoked but its discovery found nothing and the run was not
completed — this is NOT "no test suite".** All seven of the skill's discovery
priorities fall through on this repo (no `.claude/config.yml` `test_command`, no
`package.json`, no root `Makefile` `test:` target), while **15 test scripts
exist and CI executes every one of them.** This is the third task to hit it; the
durable fix is a `.claude/config.yml`, which was out of this slot's `## Allowed`
scope. See Follow-ups.

What was actually run, during the audit:

- **14/14 test scripts pass.** `build.sh` was the only one not run — it needs
  the X11 build toolchain and is executed by CI's `build-suckless` job inside
  the Fedora container.
- **Two new suites**, 24 and 19 assertions. **19/19 mutations caught**,
  including the two that matter: claiming a foreign file in the manifest, and
  one `theme.conf` drifting from the archive. Two first-pass entries were
  harness bugs rather than survivors — one anchor never matched (backslash
  escaping), one "mutation" was a no-op replacement; both re-run correctly and
  both died.
- Every branch of both new deploy functions was exercised in a **fully
  sandboxed `$HOME`** (all four XDG vars, not just `HOME` — `MANIFEST_DIR`
  derives from `XDG_STATE_HOME`, and a bare `HOME=` writes into the real
  manifest `uninstall.sh` acts on).
- `tests/lint.sh` passes. **markdownlint is not installed on this host, so its
  "ok" is a skip, not a check** — CI's `--strict` is what enforces it on the
  eight markdown files this task touched.

**Unchanged and still unproven:** none of this has run on Fedora hardware.

## Follow-ups

- **`/test` cannot discover this repo's suite.** Third occurrence. Fix is a
  `.claude/config.yml` with `test_command` — deliberately not done here, since
  that path is outside this slot's `## Allowed` block and would have tripped the
  drift hook. Worth its own micro task.
- **Giving `starship` a `SCRIPT` manifest row is now viable.** The only stated
  objection in `install-pkg.sh` was that it would appear under a prompt reading
  "dwmblocks block scripts" — this task generalised that prompt. Adding the row
  is a behaviour change (uninstall would start deleting a binary the user may
  upgrade via `starship upgrade`), so the comment was corrected to say so and
  the decision left open rather than made in passing.
- **Nothing watches the vendored tarball** for upstream releases. Same gap as
  the suckless patches; in scope for the queue's dependency-automation item.
- `dots theme --help` has one cosmetically misaligned continuation line, because
  the substituted name is shorter than `theme-apply.sh`. Fixing it means either
  padding (odd spacing) or editing the load-bearing `sed -n '3,7p'` range.

## Lessons

- **The queue entry was wrong in two independent ways, and both were only
  visible by reading the code and the reference implementation.** Half the item
  was already done; the trust decision it warned about was not the one the
  reference actually makes. This repo has now recorded "the queue entry
  described a symptom, not a specification" three times — the entry is a
  pointer, not a brief.
- **Stage after fixing, not before auditing.** `git add -A` was run to compute
  the audit tier *before* the audit fixes existed, so the reviewer read a stale
  index missing three of them and BLOCKed on the externally visible one (`xz`
  undeclared while `tar -xJf` shipped). It was right about the committed state
  and wrong about the working tree. **Second consecutive task where the reviewer
  caught a gap between claim and reality.**
- **A test that reports nothing may be a broken test, not a passing one.** The
  completion's flag extraction returned empty for all four subcommands; the
  first probe blamed the code, but the probe's own nested quoting was broken.
  Re-run from a file, it showed a *real* bug in two of four cases: `version` and
  `uninstall` write usage as `usage: cmd [--json]`, so the token is `[--json]`
  and never matched `--*`. **The repo has two usage styles and the first
  implementation only handled one.**
- **A function sitting exactly on the 60-line cap is a latent hard stop.**
  `restore_cursor_theme` measured 60 — compliant, and one line from blocking the
  next edit in a repo with a documented history of cap-forced splits.
