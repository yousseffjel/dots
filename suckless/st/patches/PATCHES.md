# st patches — merge notes

## st-xresources-signal-reload-20260805-local.diff

**Source**: adapted from the upstream st xresources-with-reload-signal
patch (`st.suckless.org/patches/xresources-with-reload-signal/
st-xresources-signal-reloading-20220407-ef05519.diff`, by wael). "local"
in the filename flags this as a hand-adapted merge, not a verbatim
upstream commit.

**Why the signal-reload variant specifically, and not the plain
xresources patch**: st doesn't get restarted to pick up a new theme —
each `st` process is a live terminal session with a shell/program
running inside it, so a restart-based reload (dwm's approach) would kill
whatever the user is running. The signal-reload variant instead
registers a `SIGUSR1` handler (`reload()`) that re-reads X resources and
re-derives the color palette in place: `killall -USR1 st` updates every
running terminal without touching its shell.

**Merge context**: st ships with **zero** other patches applied in this
repo (`suckless/st/patches/` was empty before this file), so this was a
clean apply against the vendored `x.c` — no conflict resolution needed,
unlike dwm.

**Scope trimmed from upstream**: the reference patch also loads `font`,
`termname`, `blinktimeout`, `bellvolume`, `borderpx`, `cursorshape`,
`cwscale`, `chscale`, and `reverse-cursor` as resources, and its
`reload()` unloads/reloads fonts and forces a `cresize()` (fake resize)
plus a raw `ttywrite("\033[O", ...)` escape write. Only shipped:

- **Resources**: `st.background`, `st.foreground`, `st.color0`..
  `st.color255` (the loop upstream uses, which is a superset of the
  spec's `st.color0`-`st.color15` — kept the full 256-color loop since
  it's the same cost and st supports the extended palette already),
  `st.cursorColor`. No font/geometry/timing resources — out of scope
  for a *color* theming engine.
- **`reload()` body**: `xrdb_load(); xloadcols(); redraw();` only. Font
  reload was dropped (nothing here touches font resources, so
  `xunloadfonts()`/`xloadfonts()` would be dead work). `cresize()` was
  dropped — it's a "pretend the window resized" trick to force a
  full redraw; `redraw()` (`tfulldirt(); draw();`) already does that
  directly without faking a resize event that could confuse a program
  watching for real `SIGWINCH`-driven geometry changes. The trailing
  `ttywrite("\033[O", ...)` (an unexplained upstream escape write) was
  dropped as unnecessary for a color-only reload.

**One correctness fix over upstream**: the reference `xrdb_load()` opens
its own `Display` via `XOpenDisplay(NULL)` on every call (startup *and*
every `SIGUSR1`) but never calls `XCloseDisplay()` on it — a display
connection leak on every theme reload. This version adds
`XCloseDisplay(dpy)` before returning.

**Bug caught by the reviewer gate, fixed before commit**: an earlier
draft of this patch also added an `XrmDestroyDatabase(xrdb)` call at the
end of `xrdb_load()`, reasoning (wrongly) that it mirrored the
`XCloseDisplay` fix above. It doesn't: `XrmGetResource` hands back
pointers *into* the database's own string storage, not copies —
`colorname[i] = ret.addr` stores one of those pointers directly.
Destroying the database right after loading freed the strings
`colorname[]` still pointed to, so `xloadcols()` (called immediately
after, both at startup via `xinit()` and on every `SIGUSR1` via
`reload()`) read from freed memory — a use-after-free on every single
launch, not just on reload. The independent reviewer subagent caught
this before commit; the fix is to *not* destroy the database at all
(see the comment left in `xrdb_load()`), matching upstream's own
behavior — upstream never frees it either, for the same reason. The
trade-off is a small intentional per-reload memory leak (each
`SIGUSR1` abandons the previous reload's database) instead of a crash;
acceptable for a database on the order of a few KB that would need
thousands of reloads in one session to matter.

**Signal-handler safety note**: `reload()` calls `XOpenDisplay`,
`malloc` (via `xloadcols()`), and other non-async-signal-safe functions
directly from a `signal()`-registered handler. This is the same
pragmatic pattern already used elsewhere in this repo (dwm's
`restartsig` patch calls `quit()`, which is not async-signal-safe
either, straight from `sighup()`) and matches how the upstream st patch
itself is written — not hardened further here, to stay consistent with
the existing codebase style rather than introduce a one-off
self-pipe/flag-based signal pattern found nowhere else in this project.

**Build verified**: `make clean && make` — clean compile. `-Wall -Wextra`
shows only the same class of pre-existing warnings already present
throughout vanilla `x.c` (missing-field-initializers on
`MouseShortcut`, sign-compare, unused-parameter on other handler-style
functions) — one new `-Wunused-parameter` on `reload(int sig)`'s unused
`sig`, which is required by `signal()`'s handler signature and mirrors
the same pattern dwm already uses for `sighup(int unused)`.
