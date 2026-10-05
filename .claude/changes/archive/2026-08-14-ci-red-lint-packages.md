# ci-red-lint-packages
Date: 2026-08-14
Files: 8 | Lines: +107/-18 (of which the fixes are 6 files; the rest is this
log and the state files)

## What changed

Both red CI jobs on `main`, fixed at the cause rather than at the symptom.

**1. `lint` — the linter, not the code, was the variable.**
`tests/autostart-daemons.sh` disables the "unreachable function body" finding
on the two colour helpers it overrides inside a subshell. shellcheck **0.10.0
split that finding out of SC2317 into SC2329**, so the existing
`disable=SC2329` was honoured by the dev host's 0.11.0 and ignored by the
runner image's older copy, which reported SC2317 and failed the job. Two
changes:

- the directive now disables **both** codes, so the file is clean under either;
- **`.github/workflows/ci.yml` pins shellcheck** the way it already pins shfmt
  and markdownlint — a checksum-verified release tarball installed into
  `$HOME/.local/bin`, which goes on `$GITHUB_PATH` (it *prepends*, so it wins
  over the image's `/usr/bin` copy). `.pre-commit-config.yaml` had declared
  `shellcheck-py` **v0.11.0.1** all along; CI is now that same shellcheck.

That pin is a second declaration of one version, so it is guarded rather than
commented: **new `tests/shellcheck-pin.sh`** reads both numbers out of the
shipped files (ignoring shellcheck-py's fourth, packaging-only component) and
fails the build when they disagree. CI globs `tests/*.sh`, so it needed no
wiring.

**2. `install-dry-run` — four retired package names in `packages/extra.lst`.**

| was | now | why |
| --- | --- | --- |
| `vim` | `vim-enhanced` | no binary package by that bare name resolves on f43 **or** f44 |
| `wget` | `wget2-wget` | same — gone on both; this is the shim whose stated purpose is to provide `/usr/bin/wget` |
| `p7zip` + `p7zip-plugins` | `7zip` | still on f43, gone on f44; upstream 7-Zip is the successor, and there is no `7zip-plugins` |

Each retirement is recorded in the file's `NOT LISTED HERE, deliberately`
block so nobody "restores" it later — the same treatment `xcolor`, `unrar` and
`brightnessctl` already have.

**Docs reconciled:** `TESTING.md` (entry for the new test), `CLAUDE.md` (the
linters are now all pinned, and why), `ROADMAP.md` §4.2's `vim` row.

## Why

`install-dry-run` and `lint` were both red on `main` at `d368e9c`. The package
failures are not cosmetic: `extra.lst` is best-effort, so an install would
have carried on and simply not shipped vim, wget or 7z, with one yellow line
each in the closing summary. The lint failure blocked the job outright.

The shellcheck pin is the part that stops this recurring. Two of three linters
were pinned; the third was "whatever the runner image ships", and a linter that
renumbers findings between releases is not a fixed measuring stick. The
directive fix alone would have gone green today and broken again on the next
image bump or the next renamed code.

## Assumptions

- **Type B — pinning shellcheck rather than only widening the directive.** The
  one-line fix (both codes disabled) is shipped too and is what makes the file
  robust anywhere; the pin is what makes CI reproducible. Alternative
  considered: leave CI on the image's shellcheck and disable codes as they
  appear. Rejected — that is an open-ended series of one-line fixes, each
  discovered by a red build. If incorrect: delete the `SHELLCHECK_VERSION` /
  `SHELLCHECK_SHA256` env pair, restore the `apt-get` fallback in the "Install
  linters" step, and delete `tests/shellcheck-pin.sh`.
- **Type B — `7zip` alone replaces both p7zip packages.** No codec-parity claim
  is made; RAR extraction on this roster is `unar`'s job (locked decision 8),
  and `7zip-plugins` does not exist. If a specific p7zip-plugins codec turns
  out to be missed, that is a new `extra.lst` entry, not a revert.
- **Type C — `wget2-wget` over `wget2`.** The command this repo's users type is
  `wget`; the shim provides it. Plain `wget2` installs only `/usr/bin/wget2`.

## Test coverage

- **The failure was reproduced before being fixed.** shellcheck **0.9.0** (the
  code the runner reported) was downloaded and run against
  `tests/autostart-daemons.sh` on `main`: same two lines, same SC2317, rc=1.
  After the fix: rc=0 under **both** 0.9.0 and 0.11.0.
- `tests/lint.sh --strict` rc=0. shellcheck 0.9.0 is clean across
  `scripts/**`, `tests/*.sh` and `scripts/dots` — so even an unpinned old
  linter has nothing else to say about this repo today.
- **Suite 15 → 16 scripts, all pass** (14 executed + `lint.sh` + `build.sh`,
  the latter compiling all five suckless programs on the dev host).
- `tests/shellcheck-pin.sh`: **6/6 mutations behaved as specified** — bumping
  either file alone, renaming the `SHELLCHECK_VERSION` key, and deleting the
  `shellcheck-py` hook all fail it; a fourth-component-only rev change and a
  `v`-less version string both still pass.
- **Package names verified against the Fedora mdapi for f43 AND f44** (rule 8;
  there is no `dnf` on this Arch dev host), sweeping **all 107 names in all
  four lists**, not just the changed ones, with a positive control (`git`) and
  a negative control in the same sweep. Only `thunar` came back missing, and
  that is a **probe artefact**: mdapi is case-sensitive, the package is
  `Thunar`, and CI's own `dnf list --available thunar` reports it OK on both
  legs. Noted in `extra.lst` so the next sweep does not chase it.
- `ci.yml` parses as YAML and the `lint` job's `run:` block passes `bash -n`.
  **The workflow itself has not run** — that only happens after merge.

## Follow-ups

- **Watch the first CI run after this merge.** Two things are unobserved: the
  pinned shellcheck download inside the `lint` job (it fails loudly at
  `sha256sum -c` or `install` if anything is off), and whether
  `install-dry-run` is now fully green. This supersedes nothing — the existing
  "watch the first CI run after 2026-08-10" queue item is still open for its
  own two reasons.
- **`p7zip` remains valid on f43 and is now uninstalled there.** Anyone with an
  existing f43 install keeps their old package; `7zip` is additive on the next
  run. No migration written, because `extra.lst` removals have never had one.
- The `install-container` workflow is `paths:`-filtered and this diff touches
  `packages/extra.lst`, so it will run — ~30 min per leg.
