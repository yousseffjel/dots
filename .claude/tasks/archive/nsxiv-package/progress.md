# Progress — nsxiv-package

## Status
`done`

## Steps
- [x] 1. Delete suckless/nsxiv; install-suckless.sh maps and comments.
- [x] 2. Packages: desktop.lst nsxiv, build.lst drops imlib2-devel/libexif-devel, extra.lst note.
- [x] 3. Tests: default-apps.sh provider; build/pkgname tests.
- [x] 4. Docs + CHANGELOG + scope-i decision record.
- [x] 5. Lint, run-tests, mutation check.

## Deviations
- Step 2: nsxiv went in extra.lst, not desktop.lst. desktop.lst is for a keybind, daemon or theming engine that silently does nothing; the pure file handlers mpv and file-roller are in extra.lst, and Thunar and firefox are in desktop.lst only because each backs a keybind.
- Out of plan scope: root `.gitignore` gains `suckless/nsxiv/`. Deleting the tree removes its own .gitignore, so in an existing clone `git pull` would leave config.h, version.h, *.o and the nsxiv binary untracked and visible. (`dots update` is not blocked: update.sh checks with --untracked-files=no.) The release migration deletes the directory.
- Verified: 2 mutants caught on scratch copies. Dropping nsxiv from extra.lst fails default-apps.sh ("FAIL nsxiv.desktop"); putting nsxiv back in PROGRAMS fails build.sh ("build failed: nsxiv").

## Blockers
