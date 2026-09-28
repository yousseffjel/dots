# Context — split-dwm-runtime-test

## Background
User request 2026-09-28: "do the split". Found by the codebase scan the same
day: tests/dwm-runtime.sh at 377/250, the only cap violation under scripts/,
tests/ and config/dwm/bin/.

## Prior Decisions
- scope-d locked decision 3: dwm-runtime runs inside build-suckless.
- 2026-09-03-dwm-runtime-xvfb.md: xresources + pertag are mutation-tested;
  restartsig is advisory.

## References
- .claude/changes/2026-09-03-dwm-runtime-xvfb.md
- ~/.claude/rules/foundations/file-architecture.md (250/60 caps)

## Notes
- lint.sh find at -maxdepth 2 misses 6 tracked scripts at depth 3
  (scripts/theme/*.sh x5, scripts/migrations/*.sh x1). All clean under
  shellcheck 0.11.0 and shfmt -i 4 -ci -bn as of 2026-09-28.
