# Review — packages-roster-fonts

## Audit Loop

Tier: **Medium+** (8 files, +747/-91 = 838 lines).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0 found. Rules 1/2/4/10 all hold; starship is the one name that cannot live in a `.lst` (not a dnf package), documented in both places. Highest-risk item verified by execution: parsing `extra.lst` exactly as `read_pkg_list` does yields 89 well-formed tokens with no prose leaked from the new 20-line header and `starship` correctly absent. |
| 2 | Size/Performance | ✅ | 1 found, 1 fixed **after a reviewer BLOCK**. `install-pkg.sh` 186 lines, longest function 8. The adopted `starship.toml` was 420 lines against the 250-line hard cap, and this sweep waved it through as a self-granted exception — which was the implementer's to raise, not to settle. See the Reviewer Gate below for the resolution. |
| 3 | Types/Validation | ✅ | 1 found, 1 fixed — `tests/lint.sh` caught an shfmt violation (repo uses `-bn`). `shellcheck -x` and `bash -n` clean. `pipefail` makes the `curl \| sh` pipeline fail closed; all three starship branches exercised by execution. |
| 4 | Dependencies | ✅ | 1 found, 1 fixed. `curl` is declared in `extra.lst`. **The fix mattered:** the first draft wrote `manifest_append_row PACKAGE "starship:<path>"`, and `uninstall_packages()` pipes every PACKAGE value into a single `dnf remove` — one un-removable name would have failed that call and left every other package installed. Row removed; manual removal documented instead. |

**Audit verdict:** ✅ READY

## Follow-ups surfaced by the audit

- **Terminal/bar fonts do not point at the new Nerd Font.** `dwm` and `dmenu`
  use `monospace:size=10` (resolves to DejaVu Sans Mono here) and `st` uses
  `Liberation Mono`. Installing `cascadia-code-nf-fonts` does not change that;
  glyphs will render through fontconfig's per-glyph fallback, which works but
  gives mismatched glyph metrics. Setting the font explicitly belongs to
  **sub-task 3** (alacritty) and **sub-task 7** (dwm/statusbar). `suckless/` is
  Forbidden in this plan.
- **starship is not removable by `uninstall.sh`.** Adding a `BIN` manifest
  category plus a handler in `uninstall_steps.sh` would fix it properly; both
  files are outside this plan's Allowed.

## Test Gate
**Command:** `tests/lint.sh` + `tests/pkglist.sh` (run on `slot/packages-roster-fonts`)
**Result:** ✅ PASSED — shellcheck / shfmt / markdownlint ok; package lists valid
(format, no duplicates, no core/extra overlap).

`tests/pkglist.sh` carries real weight on this diff: every token surviving
`extra.lst`'s comment-stripping is passed to `dnf install`, so it is the check
that would catch a malformed token leaking out of the new 20-line header.

**Not run:** `tests/build.sh` — compiles the vendored suckless C tree, untouched
by this diff, and needs Fedora build dependencies absent from this Arch host.

**Coverage caveat:** `tests/` is lint and validation only; nothing in it
verifies the packages actually install. That needs real Fedora hardware — an
item CLAUDE.md already tracks as open. Substantive verification for this task
was manual and is recorded in `progress.md`.

## Reviewer Gate
**Verdict:** READY (after one BLOCK -> fixed -> re-reviewed)

**Round 1 — BLOCK:** `config/starship/starship.toml` at 420 lines violated the
250-line hard cap in `rules/foundations/file-architecture.md`, and the audit
loop had self-granted an exception rather than surfacing it. The reviewer was
right on process: the user had been asked about trimming for *performance*,
never about this rule conflict, so it was a Type-A question presented as a
Type-B judgement call.

**Resolution.** Established first that `split-oversized-file` could not apply —
starship has no include/import/extends mechanism (verified against
starship.rs/config), so the choice was adopt-vs-don't, not split-vs-don't. Put
four options to the user with the trade-offs; they chose to drop sections for
toolchains the repo neither declares nor installs. 44 of 59 `[section]` blocks
removed along with their `right_format` entries — dropping only the section
would have let starship fall back to its default glyph-heavy rendering if such
a toolchain ever appeared. File is now 151 lines.

**Evidence the trim changed nothing:** right-prompt output is byte-identical to
the user's original 405-line config in a directory carrying markers for every
kept language (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`,
`pom.xml`, `composer.json`, `main.c`, `main.cpp`, `init.lua`, `script.pl`).

**Round 2 — READY:** under cap, valid TOML, no dangling module references in
either direction, nothing removed that `format` still references, and no
further issues in `packages/extra.lst` or `scripts/install-pkg.sh`.
