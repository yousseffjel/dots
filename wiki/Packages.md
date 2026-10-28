# Packages

Every package dots installs is declared in a plain-text list under
[`packages/`](https://github.com/YoussefFjel/dots/tree/main/packages). Scripts never carry inline package arrays.
This page explains the tiers, how names are checked, and how to add one.

The lists themselves are the source of truth; this page deliberately names no packages.

## The format

- One package per line, `#` for comments (whole-line or trailing), blank lines ignored.
- Parsed with `sed`, `tr` and `grep` only, by `read_pkg_list()` in
  [`scripts/install-pkg-tiers.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-pkg-tiers.sh).
  Tests extract and run that shipped function rather than reimplementing it.
- Keep the category comments (`# --- the X session itself ---` and similar) as section dividers.
- Each file's header explains its tier. Read it before adding to it.

## The tiers

Pick a tier by asking **what breaks without this package, and does that announce itself?**

| List | Read by | On failure |
| ---- | ------- | ---------- |
| `core.lst` | `install-pkg.sh` | **Aborts the run.** Only what the installer's own next step needs: git for the plugin-manager clones, zsh for the login-shell step. |
| `build.lst` | `install-suckless.sh` only | **Aborts the build stage.** The C toolchain and headers for the suckless programs. |
| `desktop.lst` | `install-pkg.sh` | **Never aborts**, but every failure is repeated in a red closing summary with its consequence. |
| `extra.lst` | `install-pkg.sh` | **Never aborts.** Failures get one yellow line in the summary. |
| `laptop.lst` | `scripts/drivers-lib.sh` only, on a laptop | **Never aborts**, best-effort like extra. |

### core: keep it tiny

A hard failure turns a renamed package into no install at all instead of a degraded one. Anything that merely
breaks a feature belongs in `desktop.lst`.

### build: owned by the build stage

`install-pkg.sh` deliberately does not read `build.lst`. `install-void.sh` runs `install-suckless.sh` straight
after the package half, and that script installs `build.lst` immediately before compiling. So
`install-void.sh --skip-suckless` needs no special handling: skip the build and the build dependencies are never
installed. CI's `build-suckless` job reads the same file, and `tests/ci-build-deps.sh` checks that it does.

`install-suckless.sh` still has inline package arrays for `pacman` and `apt-get`. They are vestigial fallbacks
from when the repo supported other distributions and are the one documented exception. Don't add a third.

### desktop: for silent failures

The criterion is that without the package a shipped keybind, an autostart daemon or the theming engine
**silently** does nothing. A package whose absence announces itself (an app that just isn't there) belongs in
`extra.lst`. Desktop failures never abort, because a degraded desktop you can log into and repair beats none.

### extra: applications and conveniences

Losing one costs you that program and nothing else.

### laptop: chassis-limited

`laptop.lst` starts with the line `# chassis: laptop`, and that line is load-bearing. `pkg_list_chassis` reads
it, so `dots doctor` (which globs every list) checks this one only where `drivers_chassis` says the machine is a
laptop. A virtual machine reads as `vm` and gets desktop behaviour. A future chassis-limited list declares itself
the same way; no consumer should name it.

### live: the live installer's target

`packages/live/` holds what [`scripts/install-live.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-live.sh)
puts into the new root. It is a subdirectory so the depth-1 glob in `dots doctor` never checks it on an
installed desktop. The name checks below cover it too.

## How a tier is installed

`install_tier` does one xbps transaction per tier, because one transaction is far faster than one per package.
Before it, every name is checked with `xbps-query -R`: a single unknown name makes `xbps-install` install nothing,
so unknown names are reported as failures up front and left out. If the transaction still fails, it retries one
package at a time so one bad package costs only itself. Packages already installed are skipped and get no
manifest row, which is why `dots uninstall` removes only what dots itself installed.

Before any tier, the stage syncs the index, updates xbps and runs a full upgrade. Void does not support partial
upgrades.

## Consequence text in desktop.lst

In `desktop.lst`, everything after the `#` on a package line is that package's **consequence text**:

```text
somepackage    # what silently stops working without it
```

`load_consequences()` in `install-pkg-tiers.sh` reads it back to build the red summary at the end of a run, so
the user is told what they lost, not just a package name. `read_pkg_list()` strips the comment for the install
itself, so the fact lives in exactly one place.

[`tests/desktop-consequences.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/desktop-consequences.sh)
fails the build if a `desktop.lst` entry has no consequence text. Write it for a user reading a failure summary:
name the key, daemon or feature that dies.

## How names are checked

Package names are never guessed. Three layers check them:

1. **[`tests/pkglist.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/pkglist.sh)** checks syntax
   offline: valid characters, no empty list, no duplicate within a file, and no package in two tiers.
2. **[`tests/void-pkgnames.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/void-pkgnames.sh)** checks
   every name against `tests/fixtures/void-x86_64-pkgs.tsv`, a committed snapshot of Void's official x86_64 index
   (main and nonfree). It fails on a name that is not a Void package, and on one that is only in nonfree, because
   the package stages run before nonfree is enabled. It warns once the snapshot is over 90 days old.
3. **CI's `package-names` job** runs in a Void container and asks the live index with `xbps-query -R` for every
   name in `packages/*.lst` and `packages/live/*.lst`. This is what notices the snapshot going stale as Void
   renames and drops packages.

Refresh the snapshot with:

```sh
tests/void-pkgnames.sh --refresh
```

It needs `curl`, `zstd`, `tar` and `python3`, and is never run in CI.

### Existence is not meaning

A name being in the index does not mean it is the right package. When the obvious name might differ, download
the `.xbps` from `repo-default.voidlinux.org/current/` and list it with `tar -t` to confirm it ships the binary or
path dots actually uses. On a Void host, `xbps-query -R -f <pkg>` shows the same. Note how you checked in the
change log.

## Adding a package

1. Confirm it is in Void's **main** repository (`xbps-query -R <name>` on Void), and that it provides what you
   need.
2. Pick the tier with the question above. When in doubt between desktop and extra: would a user notice its
   absence without being told?
3. Add the line under the right section comment. In `desktop.lst`, add the consequence text.
4. Run `tests/pkglist.sh`, `tests/void-pkgnames.sh` and `tests/desktop-consequences.sh`. If
   `void-pkgnames.sh` does not know a real new package, refresh the snapshot and commit it with the change.
5. If a feature depends on it, make sure `dots doctor` reports it missing. It checks every list it globs, so a
   new entry is covered.
6. Add a CHANGELOG line if a user would notice.

A package that exists only outside Void's main repository is never added silently. Leave it out of the lists,
note the command in a header comment, and print a yellow reminder at the end of the run. See
[Contributing](Contributing#adding-a-package).

## A new tier

Tests and CI glob `packages/*.lst`, so a new list is checked the moment it exists. Never name the lists in a
consumer; a named loop silently stops covering whatever is added next.
