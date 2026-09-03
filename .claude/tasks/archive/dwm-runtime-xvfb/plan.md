# Plan — dwm-runtime-xvfb

## Goal
scope-d slot C: first-ever execution of the built dwm binary in this repo's
test suite. New tests/dwm-runtime.sh starts Xvfb, runs suckless/dwm/dwm
against it, and asserts real EWMH root-window state plus the runtime
behaviour of vendored patches — locked decision 4 requires at minimum the
xresources colour path and one pertag behaviour, with mutation-tested teeth.
Wired into build-suckless per locked decision 3.

## Scope
- tests/dwm-runtime.sh (new)
- .github/workflows/ci.yml (build-suckless job: test deps + invocation)
- TESTING.md (new test's documentation bullet)

## Allowed
- tests/dwm-runtime.sh
- .github/workflows/ci.yml
- TESTING.md

## Forbidden
- suckless/dwm/dwm.c and config.def.h (mutation-tested via temporary,
  reverted edits only — never committed)
- packages/build.lst (Xvfb/xdotool/ImageMagick/xterm are CI-test-only,
  deliberately NOT added there — see ci.yml's own comment)

## Steps
1. Prototype against a live local Xvfb+dwm to find the real mechanics
   (EWMH property names, xresources loading, keybind-driven pertag/
   fullscreen behaviour) before writing the test file itself.
2. Write tests/dwm-runtime.sh: prereq skip-loudly checks, Xvfb startup,
   EWMH assertions, xresources colour sampling, actualfullscreen, pertag.
3. Mutation-test the two required checks (xresources, pertag) against
   temporary suckless/dwm/dwm.c edits — confirm each fails the mutant and
   passes the real source, then revert.
4. Wire into ci.yml's build-suckless job (locked decision 3) with its own
   test-only dependency step, and document in TESTING.md.
5. Run the full local suite (tests/run-tests.sh) to confirm integration.

## Out of scope
- scope-d slot D (install/uninstall symmetry).
- hide_vacant_tags, dragmfact and the remaining vendored patches not named
  in locked decision 4.

## Risks
- Xvfb resets all server state when the last client disconnects unless
  started with `-noreset` — discovered empirically (see progress.md); fixed
  by always passing it.
- SIGHUP (restartsig) delivery to a backgrounded process proved unreliable
  in the interactive sandbox this was developed in, independent of dwm —
  reproduced with a plain bash trap. Mitigated by making that one check
  advisory (WARN, non-blocking) rather than removing it.
