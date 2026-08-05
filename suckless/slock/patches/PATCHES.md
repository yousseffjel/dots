# slock patches — merge notes

This is the first patch applied to slock in this repo — `patches/` did
not exist before this commit.

## slock-xresources-20260805-local.diff

**Source**: adapted from the upstream slock xresources patch
(`tools.suckless.org/slock/patches/xresources/
slock-xresources-20191126-53e56c7.diff`, by Arnas Udovicius). Applied
cleanly against vanilla `slock.c`/`config.def.h`/`util.h` — no
conflicts, since this is the first slock patch in the repo. "local" in
the filename flags this as a hand-adapted merge, not a verbatim upstream
commit.

**Resource names — a deliberate deviation from upstream**: upstream uses
generic numbered names (`slock.color0` -> `INIT`, `slock.color4` ->
`INPUT`, `slock.color1` -> `FAILED`, `slock.color3` -> `CAPS`) borrowed
from xterm's numbered ANSI palette convention. This repo names them
after what they mean instead — `slock.initcolor`, `slock.inputcolor`,
`slock.failedcolor` — matching the descriptive style already used for
dwm/st/dmenu's resource names (`normbgcolor`, not `color0`) rather than
introducing a numbered-palette convention nowhere else in this project.

**Scope trimmed from upstream**: upstream's patch assumes a `CAPS`
color slot (from slock's separate capslock-color patch, which is not
applied in this repo — `config.def.h`'s `colorname[NUMCOLS]` here only
has `INIT`/`INPUT`/`FAILED`, no `CAPS`). Dropped the `slock.capscolor`
resource entry entirely rather than referencing a color slot that
doesn't exist in this vendored source.

**No live reload — by design, not an oversight**: slock is a
short-lived, one-shot process (it exits when the screen unlocks), so
`config_init()` reads X resources once at launch. There is nothing to
reload in place; a new lock invocation just re-reads the current
`.Xresources` state naturally.

**Where `config_init()` runs**: right after `setuid(duid)` in `main()`
(matching upstream's placement) — i.e. *after* privileges are dropped,
so X resource loading runs unprivileged like the rest of slock's
runtime, not as whatever invoked it (typically root via a suid-root
`slock` binary, per this program's whole reason for existing).

**Build verified**: `make clean && make` — clean compile with
`-std=c99 -pedantic -Wall`, zero warnings.
