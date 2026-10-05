# Progress — visual-defaults

## Status
`complete`

## Steps
- [x] 1. wallpaper-default.sh
- [x] 2. theme-apply.sh hook
- [x] 3. picom inactive dim (lockstep)
- [x] 4. spice-vdagent autostart
- [x] 5. tests/wallpaper-default.sh
- [x] 6. docs

## Deviations
- scripts/uninstall-theme.sh (outside ## Scope globs): uninstall removes the theme cache, which would leave a
  ~/.fehbg pointing at a deleted generated wallpaper. Now removed too — only when it points into the cache.

## Blockers
