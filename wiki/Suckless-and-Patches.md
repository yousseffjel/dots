# Suckless and Patches

dots ships its own builds of five suckless programs: **dwm** (window manager), **st** (fallback terminal),
**dmenu** (every menu), **dwmblocks** (status bar) and **slock** (screen locker). Their sources are vendored
under [`suckless/`](https://github.com/YoussefFjel/dots/tree/main/suckless), already patched, and built with
plain `make`.

## Patches are a record, not a build step

This is the part that surprises people. Each program has a `patches/` directory of `.diff` files, but **nothing
applies them**. There is no `patch` or `git apply` call in the scripts, the tests, CI or any Makefile.

Each diff was merged into the `.c`/`.h` sources once, when it was vendored: some by a clean `patch -p1`, the
ones that conflicted by hand. The committed sources are the patched result. The diffs are kept so that:

- you can see exactly what each patch changed, and
- the tree could be rebuilt from upstream plus the recorded diffs when re-vendoring.

The list of patches is the directory itself:

```sh
ls suckless/*/patches/*.diff
```

Don't copy that list anywhere else.

### PATCHES.md

dwm, dmenu, st and slock each have a `patches/PATCHES.md`, which is the authority on what each patch
does, where it came from, and how it was merged (including conflicts resolved by hand and patches retired since).
Read the relevant entry before changing patched behaviour:

- [dwm](https://github.com/YoussefFjel/dots/blob/main/suckless/dwm/patches/PATCHES.md)
- [dmenu](https://github.com/YoussefFjel/dots/blob/main/suckless/dmenu/patches/PATCHES.md)
- [st](https://github.com/YoussefFjel/dots/blob/main/suckless/st/patches/PATCHES.md)
- [slock](https://github.com/YoussefFjel/dots/blob/main/suckless/slock/patches/PATCHES.md)

dwmblocks carries a single upstream diff; its `PATCHES.md` records only what the history shows.

### Naming and the `-local` convention

Diffs are named `<program>-<patch>-<version-or-date>-<hash>.diff`, matching where upstream ones came from.

Files ending in **`-local.diff`** were captured against this tree rather than fetched from suckless.org. Either
the upstream patch could not apply cleanly on top of the others, or the patch was written here. That is also why
a build-time apply step cannot work: a `-local` diff only applies to this tree in its patched state, in order.
Don't try to add one.

## Changing patched behaviour

A change to anything a patch introduced goes into **three places in the same commit**:

1. The source (`dwm.c`, `config.def.h`, ...).
2. The patch's `.diff`, regenerated so it still records the behaviour. For a `-local` diff, capture it against
   this tree.
3. Its `PATCHES.md` entry, saying what changed and why.

A brand new patch is the same: merge it into the source, add the `.diff` under `patches/`, add a `PATCHES.md`
entry with its source and any hand-merge notes, and add a runtime test where you can (below).

Changing ordinary configuration, such as a key in `keys[]`, is config rather than patch behaviour. Upstream diffs
keep the context lines they were published with; they are a record of what upstream shipped.

### Keybindings: dwm or sxhkd

dwm keeps window management in `config.def.h`. Media, volume, brightness, screenshot, lock and theme keys live in
[`config/sxhkd/sxhkdrc`](https://github.com/YoussefFjel/dots/blob/main/config/sxhkd/sxhkdrc), which needs no
rebuild. Never bind the same chord in both: both grab the key with `XGrabKey`, and a doubly bound key silently
does nothing. Update [KEYBINDINGS.md](https://github.com/YoussefFjel/dots/blob/main/KEYBINDINGS.md) with any
change.

## config.def.h and config.h

As upstream, each program's Makefile copies `config.def.h` to `config.h` (dwmblocks: `blocks.def.h` to
`blocks.h`) when the generated header is missing. **Edit `config.def.h`.** `config.h` is not tracked.

Because `make` never regenerates an existing `config.h`, a changed `config.def.h` would otherwise never reach an
existing install. So before every build,
[`scripts/install-suckless-headers.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-suckless-headers.sh)
checks each generated header:

- equal to its `config.def.h`: nothing to do;
- equal to some past committed `config.def.h` (never edited by the user): renamed to `config.h.pre-<timestamp>`
  so this build regenerates it;
- anything else (the user edited it): kept, with the command that shows what to merge, printed on every build.

It never deletes anything.

## Building

[`scripts/install-suckless.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-suckless.sh) is the
build entry point. It runs as part of `install-void.sh` (unless `--skip-suckless`) and on its own:

```sh
scripts/install-suckless.sh              # install build.lst, then build and install all five
scripts/install-suckless.sh --skip-deps  # rebuild after editing a source or config.def.h
scripts/install-suckless.sh --dry-run    # show what it would do
```

For each program it runs `make clean`, `make`, then `sudo make install` into `/usr/local` (the default
`PREFIX`), and records a `SUCKLESS` manifest row per installed binary so `dots uninstall` can remove them. It
also installs the dwmblocks block scripts into `~/.local/bin` (as the user, not root), and writes `autostart.sh`
and `~/.xinitrc` if they do not exist yet. See [Session and Autostart](Session-and-Autostart).

A dwm or dwmblocks already running keeps the old binary. The script ends with a report of which running copies
are stale and how to restart each in place; `dots doctor` reports the same.

For a quick compile check without installing, use `tests/build.sh` (`make clean && make` only).

## Colours come from X resources

None of the five has colours compiled in that matter at runtime. The xresources patches make dwm, st, dmenu and
slock read their colours from the X resource database (`dwm.*`, `st.*`, `dmenu.*`, `slock.*`), which the
[theming engine](Theming-Engine) generates and merges with `xrdb`. dwmblocks' block scripts source a generated
`statusbar-colors.sh` instead.

How each picks up a new palette:

- **dwm** re-execs on `SIGHUP` (restartsig) and re-reads resources at startup. Window placement, tags and
  layouts survive the restart.
- **st** re-reads resources in place on `SIGUSR1`, so open shells survive.
- **dmenu** and **slock** are short-lived and read them at the next start.
- **dwmblocks** is restarted.

Two consequences for contributors:

- Don't hardcode colours in a `config.def.h` expecting them to show; set the resource in the template.
- Don't pass `-nb`/`-nf`/`-sb`/`-sf` to dmenu from a script. Command-line colours override X resources and would
  pin the menu to fixed colours.

## Tests for the C side

- `tests/build.sh` compiles all five. CI runs it in a Void container (`build-suckless`).
- `tests/dwm-runtime.sh` runs the built dwm under Xvfb and checks real behaviour of several patches: colours from
  X resources, fullscreen, per-tag layouts, the restart, mouse drags. Its header is the current list.
- `tests/dwm-multimon.sh` does the same on two virtual monitors.
- `tests/bidi.sh` compiles the bidi helpers out of the shipped `dwm.c` and `dmenu.c` under AddressSanitizer.

The runtime tests fail, rather than skip, when the dwm binary is older than its sources, so rebuild before
running them locally. See [Testing and CI](Testing-and-CI).

## Re-vendoring upstream

Upstream releases are rare, and a re-vendor means re-merging every recorded diff in order. It is a deliberate
task, never a version bump. Use each `PATCHES.md` as the guide, and expect the `-local` diffs to need recapturing.
