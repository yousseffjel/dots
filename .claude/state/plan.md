# Plan — theming-app-templates

## Goal
Add vim and cava .dcol templates so both follow the wallpaper palette,
reimplemented against this repo's own placeholder vocabulary and template
conventions. HyDE's equivalents are GPL-3.0 and are read as design
reference only (CLAUDE.md rule 9) — no text is copied.

## Scope
- config/theme/templates/always/*.dcol

## Allowed
- config/theme/templates/always/vim.dcol
- config/theme/templates/always/cava.dcol

## Forbidden
- HyDE/
- scripts/theme/
- packages/

## Steps
1. vim.dcol -> ${confDir}/vim/colors/wallbash.vim, dcol_* -> highlight groups.
2. cava.dcol -> ${confDir}/cava/config, 8-step gradient over accent ramps.
3. Render both through the real apply-templates.sh against a live palette.
4. Verify graceful skip when neither app is installed.
5. DEVIATION: docs/THEMING.md lives in the unmerged theming-packaging
   slot, so documenting there from here would guarantee a merge conflict.
   Dropped from scope; recorded as a post-merge follow-up instead.

## Out of scope
- Packaging vim/cava in packages/*.lst (neither is a desktop dependency).
- HyDE's other app templates (chrome, discord, spotify, code).
- docs/THEMING.md section — post-merge follow-up.

## Risks
- vim colorscheme needs cterm fallbacks — mitigate by emitting gui* only
  and guarding on termguicolors.
