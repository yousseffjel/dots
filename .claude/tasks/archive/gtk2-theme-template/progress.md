# Progress — gtk2-theme-template

## Status
`done`

## Steps
- [x] 1. New template gtk2.dcol: render ${cacheDir}/gtkrc-2.0, post-command copies it to $HOME/.gtkrc-2.0
- [x] 2. install-restore-theme.sh: claim ~/.gtkrc-2.0 (or back up a pre-existing one) — generalise theme_claim_gtk_css
- [x] 3. tests/gtk2-template.sh: real engine, every shipped palette, post-command into a sandbox HOME
- [x] 4. Extend install-uninstall-symmetry.sh: fresh (engine-written file removed) + lived-in (user's original restored)
- [x] 5. Verify the rc really parses and renders dark: gtk2 in a fedora:44 container under Xvfb (scratchpad only)
- [x] 6. Docs: templates README, THEMING.md, CLAUDE.md template list, CHANGELOG

## Deviations
- Ownership policy tightened vs plan step 1/2: the post-command never replaces a non-engine ~/.gtkrc-2.0 (gtk.css does, after a backup). Reason: the post-command runs on installs that never ran the new installer, so no backup would exist.

## Blockers
