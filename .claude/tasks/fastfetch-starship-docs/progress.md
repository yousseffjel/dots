# Progress — fastfetch-starship-docs

## Status
`complete` — audit ✅ READY, reviewer READY

## Steps
- [x] 1. Refactor starship.toml to `palette = 'dots'` + marked default block; prove prompt output byte-identical.
- [x] 2. Add starship.dcol (palette only) + splice post-command; 99-prompt.zsh prefers the cache copy when newer.
- [x] 3. Add fastfetch.dcol (whole config.jsonc, Fedora logo + desktop set); install-restore-theme.sh mkdirs the dir and claims the file.
- [x] 4. Delete cava.dcol; rewrite the templates README target-style table.
- [x] 5. Document vim + fastfetch + starship in docs/THEMING.md.
- [x] 6. Reconcile CLAUDE.md, ROADMAP.md, KEYBINDINGS.md.
- [x] 7. Test: sandboxed render of both templates, mutants, full suite.

## Deviations

- **Step 7 produced two test files, not one.** `tests/theme-templates.sh`
  reached 294 lines, over the 250-line cap in `file-architecture.md`, and it
  was the only shell script in the repo over that cap — so there was no
  precedent for an exception. Split into `tests/starship-template.sh` (202)
  and `tests/fastfetch-template.sh` (203) per the prescribed remedy. The two
  duplicate a short harness on purpose, matching CLAUDE.md rule 2's stance on
  per-script colour helpers. `docs/THEMING.md` and `CLAUDE.md` references
  updated; all 8 mutants re-run against the split files.

- **Found while reconciling ROADMAP §3: picom is never launched.** It is
  packaged, configured, themed and (in sub-task 10) performance-tuned, but it
  appears in no autostart path — not `autostart.sh`, not `.xinitrc`, not
  sxhkd — and `reload.sh` only signals it *if already running*. Fixing it
  would mean editing `scripts/install-session.sh`, which is outside this
  plan's `## Allowed`, so the ROADMAP row was corrected to `⚠️ partial` and
  the fix left for a queue item rather than taken silently.

- **Not taken, deliberately:** `theme_is_ours()` in the file this task edits
  still carries the `producer | grep -qxF` SIGPIPE bug already queued in
  `MASTER_PLAN.md`, and `theme_claim_fastfetch` now calls it. It was left
  alone — it is a distinct queued item owing its own change log, and the
  impact is bounded (a redundant backup and a misleading "left untouched"
  message, only at manifest sizes far beyond the real ~3 rows).

## Blockers
