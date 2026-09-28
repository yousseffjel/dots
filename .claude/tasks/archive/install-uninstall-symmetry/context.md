# Context — install-uninstall-symmetry

## Background
scope-d slot D (the last slot of the Epic); user asked 2026-09-28 to finish it.

## Prior Decisions
- scope-d locked decision 5: prove symmetry against the manifest, not a hand list.
- decision 6: all four XDG vars. decision 8: never invoke theming post-commands.
- docs/UNINSTALL.md "What's kept, always": .zshenv ZDOTDIR line and zinit/TPM
  clones are deliberately left behind. CONFLICT surfaced 2026-09-28; user: honor.

## References
- scripts/uninstall*.sh, scripts/install-restore*.sh, scripts/global_fn.sh

## Notes
- Exploratory sandbox round trip 2026-09-28 (restore then uninstall --yes, empty
  HOME) left: .zshenv, zinit+TPM clones, mimeinfo.cache, dots-uninstall.log
  (the --yes "keep a copy of the log" answer), and empty dirs. Real manifest
  untouched (0 /tmp rows).
- Deviation from decision 5's "third snapshot equals the first": directories are
  excluded (installer mkdir -p of shared XDG dirs is not safely reversible) and
  the documented leftovers are asserted precisely rather than ignored.
