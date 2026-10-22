# Context — dwm-hyprland-mouse

## Background
User asked for Hyprland's Super+mouse move/resize freedom in dwm; chose the complete option (1+2+3+4).

## Prior Decisions
- Rule 5: diffs are a record, sources pre-patched; `*-local.diff` for hand-captured ones.
- dragmfact was baked in before tracking; its warp-to-split is superseded by dragtile.

## References
- Hyprland wiki: configuring/core/dispatchers (drag(), resize({keep_aspect_ratio})), config-options (general.snap.*, resize_on_border, resize_corner)
- bakkeby/patches @ d99bbe2: dwm-resizepoint-6.6.diff, dwm-placemouse-6.6.diff, dwm-cfacts-dragcfact-6.6_full.diff

## Notes
- Upstream dragcfact rejected: only changes cfact for both axes and warps the pointer to the centre.
- moveorplace removes "drag a tiled window to float it"; Super+MMB (togglefloating) keeps that.
