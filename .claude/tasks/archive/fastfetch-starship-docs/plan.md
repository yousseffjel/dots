# Plan — fastfetch-starship-docs

## Goal
Epic sub-task 9, the last one: theme starship (palette splice) and
fastfetch (template-only), retire cava.dcol, reconcile six stale doc claims.

## Scope
- config/starship/**, config/theme/templates/**
- config/zsh/conf.d/99-prompt.zsh, scripts/install-restore-theme.sh
- docs/**, CLAUDE.md, ROADMAP.md, KEYBINDINGS.md, tests/**

## Allowed
- config/starship, config/theme/templates, config/zsh/conf.d/99-prompt.zsh
- scripts/install-restore-theme.sh, docs, tests
- CLAUDE.md, ROADMAP.md, KEYBINDINGS.md

## Forbidden
- scripts/symlinks.sh — fastfetch is template-only (gtk.css pattern),
  config/starship already linked; neither needs an entry
- config/picom, config/dunst, packages/*.lst, suckless/**

## Steps
1. Refactor starship.toml to `palette = 'dots'` + marked default block;
   prove prompt output byte-identical.
2. Add starship.dcol (palette only) + splice post-command; 99-prompt.zsh
   prefers the cache copy when newer.
3. Add fastfetch.dcol (whole config.jsonc, Fedora logo + desktop set);
   install-restore-theme.sh mkdirs the dir and claims the file.
4. Delete cava.dcol; rewrite the templates README target-style table.
5. Document vim + fastfetch + starship in docs/THEMING.md.
6. Reconcile CLAUDE.md, ROADMAP.md, KEYBINDINGS.md.
7. Test: sandboxed render of both templates, mutants, full suite.

## Out of scope
- A shell greeting (user chose command-only).
- Trimming starship's module set — settled in sub-task 2.

## Risks
- Post-commands pkill the live session — sandbox per the test-hazard memory.
- A `palette` with no table WARNs on every prompt; repo copy needs a default.
