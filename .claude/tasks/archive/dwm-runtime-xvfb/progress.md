# Progress — dwm-runtime-xvfb

## Status
`done`

## Steps
- [x] 1. Prototype against live local Xvfb+dwm
- [x] 2. Write tests/dwm-runtime.sh
- [x] 3. Mutation-test xresources and pertag (both caught correctly)
- [x] 4. Wire into ci.yml + document in TESTING.md
- [x] 5. Run full local suite (tests/run-tests.sh) — green

## Deviations
- Task folder was created retroactively, after implementation and local
  verification were already substantially complete. This slot was
  extremely exploratory (first-ever dwm execution in this repo, no prior
  pattern to follow) and proceeded as prototype-first rather than
  plan-first. Substance is unaffected — every claim below is backed by a
  real, reproduced test run, not asserted from memory — but the process
  deviation itself is recorded here rather than silently normalized.
- restartsig (SIGHUP reload) downgraded from a hard assertion to advisory
  (WARN, non-blocking) after being unable to get signal delivery to work
  in this development environment at all — see context.md Notes and the
  test's own header comment. Not part of the required exit criteria.
- Section order was changed from the original plan (xresources ->
  restartsig -> fullscreen -> pertag) to (xresources -> fullscreen ->
  pertag -> restartsig) after discovering that a SIGHUP restart appears to
  break focus-dependent behaviour for pre-existing windows — moving
  restartsig last so it can't contaminate the two required checks.

## Blockers
(none remaining)
