# Plan — dmenu-path-cache

## Goal
dmenu_path rebuilds ~/.cache/dmenu_run only when a PATH directory is newer
than the cache, so a directory that JOINS PATH (flatpak exports/bin, VM
2026-10-06: dir 13:11, cache 13:13) is never scanned until something inside
it changes. Also rebuild when $PATH differs from the PATH the cache was built
for (recorded beside it). User chose this over an installer cache-drop.

## Scope
- suckless/dmenu/**, tests/**, CLAUDE.md, CHANGELOG.md, TESTING.md

## Allowed

## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. suckless/dmenu/dmenu_path: rebuild also when "$cache.path" != $PATH; write it after a rebuild
2. Rule 5: patches/dmenu-pathcache-20261006-local.diff + PATCHES.md entry
3. tests/dmenu-path-cache.sh: real stest compiled from the vendored stest.c (skip if no cc); a dir joining PATH older than the cache is listed; unchanged PATH is served from cache; the unpatched script misses it
4. Docs: CHANGELOG (Fixed), CLAUDE.md dmenu patch roster, TESTING.md

## Out of scope
- dmenu_run itself; rebuilding the VM (user runs install-suckless.sh)

## Risks
- CI tests job lacks cc — yellow skip, never a false pass
