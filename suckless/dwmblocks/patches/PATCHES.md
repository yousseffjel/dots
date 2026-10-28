# dwmblocks patches — merge notes

Written 2026-10-28, long after the merge: until then this directory held
the diff with no notes, so what follows is only what the history records.

## dwmblocks-statuscmd-20210402-96cbb45.diff

**Source**: the upstream dwm statuscmd patch's dwmblocks half
(Daniel Bylinka, 2021-04-02, against dwmblocks `96cbb45`). It makes each
block's text carry its signal number, so dwm's statuscmd patch can tell
which block was clicked, and sends the button to that block's script.

**Merged**: with the rest of the vendored trees in `66996a8` (2026-08-04).
That commit does not record whether the diff applied cleanly. The same
commit also reworked `dwmblocks.c` for signal safety, timing and bounds,
so the vendored source is the diff plus those fixes; a re-vendor from
upstream needs both, and the fixes have no `.diff` of their own.
