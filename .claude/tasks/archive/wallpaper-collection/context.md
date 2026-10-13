# Context — wallpaper-collection

## Background
User request 2026-10-13: "add them [the cleaned wallpaper repo] to the project". User chose:
installer clones it; ~/Pictures/wallpapers; random wallpaper on each install.
The repo was cleaned/renamed earlier the same session (189 images, flat, <category>-<desc>[-nord].<ext>), pushed as 5da2d12.

## Prior Decisions
- MASTER_PLAN: "a theme carries no wallpapers/" and themes/dark/wallpapers/README.md: no images committed (size, licences). Respected: nothing enters dots.
- Rule 4: third-party sources are a trust decision — this is the user's own repo, explicitly requested.
- zinit/TPM pre-clones in install-restore.sh are the precedent for install-time git clones.

## Assumptions (Type B)
- Clone into `<pictures>/wallpapers/dots/`, not the dir itself: theme-apply seeds ~/Pictures/wallpapers with the generated gradient, so on every existing install that dir already exists and "skip if exists" would never clone. wallpaper.sh's find recurses, so the subdir is picked up.
- Download is ~410 MB (the shallow clone carries every current image) — NOT the ~80 MB the option text said; that was the size of the last push.

## References
- scripts/install-restore-flatpak.sh / uninstall-flatpak.sh — the write-if-absent / revert-if-unchanged pattern.
- scripts/theme/wallpaper.sh — WALLPAPER_DIR, list_wallpapers (find -L, recursive).
- scripts/install-session.sh:105-117 — .xinitrc first-login `dots theme dark`.
- scripts/install-restore-theme.sh:186-195 — graphical initial apply.

## Notes
