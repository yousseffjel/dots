# Plan — ci-build-deps-from-lst

## Goal
CI's `build-suckless` job hardcodes 12 dnf package names in a comment
claiming to match `install-suckless.sh`'s `install_deps()` exactly — it
doesn't; `packages/build.lst` declares 13, and `patch` is the one missing.
Make the job read `packages/build.lst` directly (reusing the existing
`read_pkg_list()` sed/tr/grep pattern already duplicated 3x, not adding a
4th restatement), and add a guard test so a hardcoded list can't reappear.

## Scope
- .github/workflows/ci.yml (build-suckless job, "Install build dependencies" step)
- tests/ci-build-deps.sh (new)

## Allowed
- .github/workflows/ci.yml
- tests/ci-build-deps.sh

## Forbidden
- packages/build.lst (content unchanged — decision 7, out of scope here)
- scripts/install-suckless.sh, suckless/**

## Steps
1. Replace the hardcoded `dnf install -y ...` line with dynamic parsing of
   `packages/build.lst`; fix the stale "matches install_deps() exactly" comment.
2. Write tests/ci-build-deps.sh: extract the step's run block from ci.yml,
   shim `dnf` on PATH to capture argv, execute the block, assert the
   captured package set equals `read_pkg_list(packages/build.lst)` exactly.
3. Run tests/lint.sh, tests/pkglist.sh, tests/ci-build-deps.sh locally.
4. Change log: note `patch` is now installed by CI but still unused by any
   build step (decision 7 — the rule-5 correction is a separate queue item).

## Out of scope
- CLAUDE.md rule 5 / build.lst patch-justification correction (queue item).
- scope-d slots B, C, D.

## Risks
- No dnf on dev host (Arch) — mitigated by shimming `dnf` as a fake binary
  on PATH rather than requiring a container.
