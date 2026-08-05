# Progress — theming-xresources-patches

## Status
`ready-for-commit` (audit-loop ✅ READY; reviewer BLOCK → fixed → re-verified)

## Steps
- [x] 1. Hand-merge dwm xresources patch against 10 existing patches
- [x] 2. Apply st xresources-signal-reload patch (clean apply)
- [x] 3. Hand-merge dmenu xresources patch against 7 existing patches
- [x] 4. Apply slock xresources patch (clean apply)
- [x] 5. Write PATCHES.md per tool
- [x] 6. Verify `make` succeeds for all 4 tools
- [x] 7. Reviewer gate: BLOCK found (st use-after-free) → fixed → rebuilt clean

## Deviations
- Trimmed all 4 upstream patches to color-only resources (dropped font/
  geometry/timing resource entries and dwm's Mod+F5 hotkey) — documented
  per-tool in each PATCHES.md, matches the user's spec which only asked
  for color resources.
- dmenu: moved `xresupdate()` call to the top of `main()` (before CLI arg
  parsing) with its own temporary `Display` connection, rather than after
  `XOpenDisplay()` — needed to preserve `-nb`/`-nf`/`-sb`/`-sf` CLI-flag
  precedence over X resources. Matches upstream's own approach once
  re-read carefully; not a deviation from upstream, just a correction of
  an initial draft that would have gotten the precedence backwards.
- st: dropped `cresize()` and the trailing `ttywrite("\033[O", ...)` from
  upstream's `reload()` — `redraw()` alone is sufficient for a color-only
  refresh; documented in st's PATCHES.md.

## Blockers
(none — the one BLOCK-level reviewer finding is fixed, see below)

## Reviewer Gate
**Verdict**: BLOCK (first pass) → fixed → clean rebuild verified.

**Finding**: `suckless/st/x.c` `xrdb_load()` called `XrmDestroyDatabase(xrdb)`
right after populating `colorname[]` from that database's `XrmGetResource`
results. `XrmGetResource` returns pointers into the database's own string
storage, not copies, so destroying it immediately freed the memory
`colorname[]` now pointed to — a use-after-free hit by `xloadcols()` on
every st launch (via `xinit()`) and every `SIGUSR1` reload.

**Fix**: removed the `XrmDestroyDatabase()` call; the database is now
deliberately left alive for the process to keep the color strings valid
(matches upstream's own `xrdb_load()`, which never destroys it either —
a small intentional per-reload leak, not a crash). Documented in
`suckless/st/patches/PATCHES.md` under "Bug caught by the reviewer gate".
Rebuilt `st` clean after the fix.
