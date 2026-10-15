# void-i1-identity — I-1: target is Void; install-fedora.sh → install-void.sh

## What changed
- `git mv scripts/install-fedora.sh scripts/install-void.sh`; every live
  reference rewritten (31 files: scripts, tests, install-container.yml, docs).
  CHANGELOG past entries, HANDOFF.md and ROADMAP.md body keep the old name on
  purpose, because they are history.
- Identity text says Void glibc with a "port in progress" note: CLAUDE.md
  header, README, CONTRIBUTING, ROADMAP banner, the installer header,
  MASTER_PLAN `## Active`, and a CHANGELOG [Unreleased] Changed line.
- Scope file: zig decision locked (official tarball pinned by sha256).

## Key Technical Decisions
- Name `install-void.sh`, not a neutral `install.sh`: it matches the
  one-distro identity and stays greppable.
- CLAUDE.md gets one superseding paragraph saying everything below it still
  describes Fedora, rather than rewriting its rules now. Each sub-task
  rewrites the rules it ports.
- Sub-tasks commit directly on `void`, which acts as the Epic's main branch,
  instead of slot/<slug> branches cut from `main`, which stays Fedora.

## Assumptions Made
- (B) The installer works on neither distro until I-3..I-8 land; the branch
  accepts that.

## Test coverage
- `tests/run-tests.sh`: 74 OK, exit 0. `tests/lint.sh --strict`: shellcheck,
  shfmt, markdownlint pass. Reviewer: READY.
- Audit found and fixed 2 issues: the sed sweep also hit the 3 history docs
  (restored), and a duplicate `### Changed` heading in CHANGELOG (merged).

## Follow-ups
- I-2: remap `packages/*.lst` to Void names + a repodata-index test.
