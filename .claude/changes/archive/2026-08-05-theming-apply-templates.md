# theming-apply-templates
Date: 2026-08-05
Files: 1 (scripts/theme/apply-templates.sh, new) | Lines: +201

## What changed
- Added `scripts/theme/apply-templates.sh [--palette PATH] <always|theme|all>...`
  — sub-task 3/7 of the theming-engine Epic. The template engine:
  reads a dcol palette, then for every `*.dcol` under
  `config/theme/templates/{always,theme}/` parses line 1 as
  `target_path|optional_post_command`, expands `${confDir}`/`${cacheDir}`
  in that header, substitutes `<wallbash_NAME>` placeholders throughout
  the body, writes the result to the target, and runs the post-command.
- `always/` vs `theme/` groups are selectable per invocation, matching
  the spec's "always on every wallpaper change, theme only on theme
  switch" split. `--palette` lets a static theme's own `colors.dcol`
  drive the same engine (needed by sub-task 6's `theme-apply.sh`).
- Missing target parent directory -> yellow skip, never fatal (the
  "app not installed" signal). Failing post-command -> yellow warn,
  continue. Final summary reports written and skipped counts separately.
- Writes are atomic (`mktemp` + `mv`), and both temp files are removed
  on every exit path via `trap ... EXIT INT TERM HUP`.

## Why
Sub-task 3 of `.claude/tasks/scope-a-theming-engine.md` — the
substitution step between `colors.dcol` (sub-task 2) and the actual
templates (sub-task 4). Reimplements HyDE-Project/HyDE's `fn_wallbash`
(local untracked reference clone, CLAUDE.md rule 9 — read as a design
reference, never sourced or shelled out to at runtime).

## Key Technical Decisions
Three deliberate divergences from the HyDE reference implementation,
each tightening a behavior rather than reproducing it:

1. **Parse the palette, never `source` it.** HyDE does `set -a; source
   "$dcol_file"; set +a`. A `.dcol` is strictly `dcol_NAME="VALUE"` lines
   plus `#` comments, so a line parser reads it exactly as well — without
   granting arbitrary bash in that file the right to execute. This
   matters specifically because `--palette` points at theme-supplied
   `themes/<name>/colors.dcol` files, which are not necessarily
   first-party: sourcing would make installing a third-party theme
   equivalent to running its author's shell script.
2. **Positive allowlist on values** (`[A-Za-z0-9 ,.:#%()/+_-]`), not just
   "don't execute it here". Rejecting execution at parse time is not
   sufficient on its own, because some generated targets *are* shell
   files — sub-task 4's `statusbar-colors.sh` is explicitly designed to
   be sourced by dwmblocks block scripts. A literal `$(...)` passed
   through into one would execute later, at *its* source time, one step
   removed. Verified: before the allowlist, `dcol_txt1="$(touch PWNED)"`
   was written verbatim into the rendered config; after, it is rejected
   at parse time with a loud warning.
3. **No `eval` for header path expansion.** HyDE does `eval
   target_file="$(head -1 ... )"`. Two known tokens are substituted as
   plain strings instead — same result, no shell invocation.

Post-commands still run via `bash -c`, deliberately: a template's
post-command is first-party repo content (sub-task 4), the whole point
of the field is to run a command, and it runs synchronously so failures
are visible (HyDE backgrounds them with `&` + `disown`).

## Assumptions
- **Type B** — `always/` and `theme/` are processed in the order given on
  the command line, sequentially, not in parallel. HyDE uses GNU
  `parallel`. Rejected: adds a dependency for a handful of sed passes,
  and serial execution makes failures readable. If incorrect: the loop is
  the obvious place to fan out.
- **Type C** — templates are discovered by plain glob per group, not
  HyDE's multi-directory `find` with dedup-by-basename (that exists to
  let a user config dir shadow a system one; this repo has one source).

## Test coverage
- No shell test suite in this repo — verification is `shellcheck` (clean),
  `shfmt -i 4 -ci -bn -d` (clean), and live runs:
  - Full pipeline: `colorgen.sh <wallpaper>` -> `colors.dcol` ->
    `apply-templates.sh all` -> correct rendered target, zero warnings.
  - Placeholder correctness: `<wallbash_pry1>` does **not** partial-match
    inside `<wallbash_pry1_rgba>` (patterns are anchored on the closing
    `>`); both resolve to their own values in one pass.
  - Hostile palette: bare commands, `$(...)`, backticks, and `;`-chaining
    all rejected at parse time; zero code execution; no shell
    metacharacters survive into rendered output.
  - Oversized palette: a 1.5 MB / 60,003-rule palette renders correctly.
    An earlier draft passed the sed program as a single argument and died
    with `Argument list too long`; now written to a temp file and used
    via `sed -f`, which has no `ARG_MAX` ceiling.
  - Graceful degradation: missing target dir skips, failing post-command
    warns, both non-fatal; counts reported accurately.
  - Error paths: no group, missing palette, and empty/no-`dcol_`-entries
    palette all exit 1 with a clear message.
  - No temp-file leaks across any of the above.
- Reviewer subagent: 3 passes. Pass 1 verified behavior and raised a WARN
  on the `source` injection surface; pass 2 confirmed the parser fix
  closed every payload it tried and raised a second WARN on the ARG_MAX
  ceiling; pass 3 (verifying the `sed -f` fix) was interrupted before
  reporting, so its checks were completed in-thread instead — including
  the temp-file-cleanup review that pass was scoped to, which is what
  surfaced the un-trapped per-template temp file now fixed here.

## Follow-ups
- Sub-task 4 writes the real templates against this engine's contract
  (`target|post_command` header, `<wallbash_*>` placeholders).
- The value allowlist is intentionally conservative. If a future template
  needs a value form it rejects (it currently covers hex, `R,G,B,A`
  tuples, `rgba(...)`, percentages, color names), widen the character
  class — the per-value sed escaping is already in place to stay correct
  if that happens.
