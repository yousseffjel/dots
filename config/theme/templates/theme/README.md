# `theme/` template group

Templates here are processed **only on a theme switch**
(`scripts/theme/theme-apply.sh`), not on every wallpaper change.

It is intentionally empty right now. All five templates this engine ships
(`xresources`, `dunst`, `picom`, `gtk`, `statusbar`) are purely
color-driven, so they belong in `always/` — they need to re-render every
time the wallpaper changes, not just when a named theme is selected.

Put a template here when it depends on something a *theme* defines but a
*wallpaper* does not, **and is still derived from the palette**. Such a
template would produce the same output for every wallpaper, so re-rendering
it on each wallpaper change would be wasted work.

**The obvious candidates are already handled without a template.** The GTK
theme name, icon theme, cursor theme and font from
`themes/<name>/theme.conf` are rendered into `settings.ini` and
`xsettingsd.conf` by the writers in
`scripts/install-restore-theme-identity.sh`, which `theme-apply.sh` calls on
every switch (2026-08-12). A `.dcol` was rejected for those: none of the
values is palette-derived, so the template engine would substitute nothing
and rewrite an identical file — and it would still need a second mechanism
for the no-clobber rule, since a template cannot ask the manifest whether a
file is ours. Do not re-add them here.

Format is identical to `always/`: line 1 is
`target_path|optional_post_command`, the body uses `<wallbash_NAME>`
placeholders. See `docs/THEMING.md` for the full contract.
