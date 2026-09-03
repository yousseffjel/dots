# Context — dwm-runtime-xvfb

## Background
scope-d slot C (`.claude/tasks/scope-d-verification-harvest.md`), harvest
item #1 from the 2026-08-24 dwm-titus comparison — the highest-value item:
"dwm itself is exercised live under Xvfb ... dots has never executed dwm in
a test at all."

## Prior Decisions
- Locked decision 3: extend build-suckless rather than add a new CI job —
  that job already builds dwm in a Fedora container on both matrix legs.
- Locked decision 4: assert the vendored patches, not just vanilla dwm.
  Minimum bar: xresources colour path + one pertag behaviour, with
  deliberate mutations caught. xresources, pertag, hide_vacant_tags,
  restartsig and actualfullscreen are all named as "worth reaching."

## References
- `suckless/dwm/patches/PATCHES.md` — xresources entry: resource names
  (`dwm.normbgcolor` etc.), and why `restartsig`'s `kill -HUP` full-restart
  was chosen over an in-place `xresreload()` hotkey.
- `suckless/dwm/dwm.c` — `xresupdate()`/`xresload()` (top of `main()`,
  before `setup()`); `sighup()` -> `quit()` -> `if(restart) execvp(...)`;
  `view()` (the plain single-tag switch bound by TAGKEYS) vs. the
  Ctrl-modified toggle variant — the pertag mfact restore lives in `view()`
  at the line `selmon->mfact = selmon->pertag->mfacts[...]`, NOT in the
  toggle variant (a first mutation attempt targeted the wrong function and
  proved nothing — see Notes).
- `config.def.h` — `MODKEY` is `Mod1Mask` (Alt, not Super — dwm's own
  compiled-in keybinds are separate from dots' sxhkd-bound Super keys), and
  `borderpx = 2`.

## Notes (research findings from developing this test)

**Xvfb `-noreset` is load-bearing.** Without it, the X server resets ALL
state (properties, `RESOURCE_MANAGER`) the instant zero clients are
connected. A short-lived `xrdb -merge` or `xsetroot` would report success
and then vanish before the next client (or dwm's own startup) read it back,
because the writer's connection closed before anyone else connected. Proven
with a minimal `xprop -root -set` / `xprop -root <name>` round-trip that
failed without the flag and succeeded with it.

**The EWMH readiness race.** `dwm.c`'s `setup()` sets root's
`_NET_SUPPORTING_WM_CHECK` one `XChangeProperty` call before
`_NET_SUPPORTED`. Polling for the first property as a "dwm is ready"
signal races the second — caught because the failure mode is deceptive:
`xprop -root _NET_SUPPORTED` on a not-yet-set property prints
"`_NET_SUPPORTED:  not found.`", which still contains the substring
"`_NET_SUPPORTED`" and spuriously satisfies a naive `grep -q "$atom"`
self-check. Fixed by polling for the LATER property instead.

**Border-pixel sampling offset.** The right border's visible pixels sit at
`x + width + border_width`, not `x + width` as X11 border theory would
suggest — verified empirically by scanning column-by-column across the
boundary with ImageMagick, not derived from documentation. Not fully
explained; adopted as measured fact with a comment saying so.

**SIGHUP delivery to a backgrounded process is unreliable in the
interactive sandbox this test was developed in**, independent of dwm
entirely — reproduced with a minimal `bash -c 'trap ... HUP; sleep 5' &`
that never caught its own HUP either, and confirmed via
`/proc/<pid>/stat`'s `starttime` field NOT changing after `kill -HUP`
(though that specific check was later understood to be inconclusive on its
own, since `execve()` does not reset a process's recorded start time
either way). Made the restartsig assertion advisory (WARN, not FAIL) as a
result — see the test's own header comment for full reasoning.

**Restart's effect on pre-existing windows.** After a genuine SIGHUP
restart (confirmed via the check-window ID changing), keybind actions that
guard on `selmon->sel` (e.g. `togglefullscr()`) appeared to no-op against
windows that existed before the restart, and `_NET_ACTIVE_WINDOW` appeared
stale. Whether this is a real `scan()`/restart-recovery gap in dwm or an
artifact specific to this test's window-tracking is NOT resolved here —
worked around by running all focus-dependent checks before any restart,
and verifying the restart itself against a freshly-spawned window. Flagged
as a follow-up rather than investigated further, given restartsig is
already advisory-only.

**A first mutation attempt proved nothing.** Neutering the pertag mfact
restore inside `toggleview()` (the Ctrl+tag variant) had zero effect on the
test, because the keybinds actually exercised (`alt+1`/`alt+2`) call the
plain `view()` function, which has its OWN separate restore line. Caught
only by re-reading `dwm.c` after an unexpectedly-green mutant run, not
assumed — a case of "the mutation you wrote isn't the one the code path
you're testing actually goes through," worth recording rather than
silently fixing and moving on.
