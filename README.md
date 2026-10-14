# dots

[![CI](https://github.com/yousseffjel/dots/actions/workflows/ci.yml/badge.svg)](https://github.com/yousseffjel/dots/actions/workflows/ci.yml)

Personal dotfiles + a suckless-based dwm/X11 desktop bootstrap for Fedora.
See `CLAUDE.md` for the full project map and installer usage.

## The `dots` command

The installer symlinks `scripts/dots` to `~/.local/bin/dots`, giving one
user-facing command on `$PATH`:

```sh
dots theme --list             # or: dots theme dark, dots theme --wallbash
dots wallpaper --select       # or: --random, or an image path
dots version --json
dots doctor                   # what is broken, and the command that fixes it
dots drivers --dry-run        # GPU video decoding, firmware, microcode (docs/HARDWARE.md)
dots uninstall --dry-run
```

Each subcommand forwards its arguments verbatim to the script that implements
it, so `dots theme --list` is exactly `scripts/theme/theme-apply.sh --list` and
every script stays runnable on its own. `dots --help` lists what is available;
`dots <subcommand> --help` shows that subcommand's options.

## Development

This repo lints shell scripts (shellcheck + shfmt), Markdown
(markdownlint), and validates the suckless build + package lists in CI —
see `.github/workflows/ci.yml`, `.github/workflows/install-container.yml`
and `TESTING.md`. `CONTRIBUTING.md` covers the conventions and how to cut a
release.

Install the pre-commit hooks once so the same checks run locally before
every commit:

```sh
pip install pre-commit
pre-commit install
```

Run them on demand against the whole repo (not just staged files) with:

```sh
pre-commit run --all-files
```

## Versioning

This repo follows semver via the `VERSION` file at the repo root. What
changed in each version is in `CHANGELOG.md`.
`dots version` (`scripts/version.sh`) prints the repo version alongside
what's actually installed (read from the manifest at `~/.local/state/dots/manifest`,
written by `install-fedora.sh`).

- **Patch** (`0.1.0` → `0.1.1`): fixes, package-list corrections, or
  anything that doesn't change what `install-fedora.sh` deploys or how —
  nothing on an existing install needs to change to pick it up.
- **Minor** (`0.1.0` → `0.2.0`): additive, backward-compatible changes — a
  new config file gets symlinked, a new suckless patch, a new optional
  package — that may still need a migration step on an existing install
  (e.g. seeding a new directory). Every bump ships a
  `scripts/migrations/<from>-to-<to>.sh`, even a no-op one, because
  `scripts/migrate.sh` stops at a step with no script;
  `scripts/migrations/0.1.0-to-0.2.0.sh` (the first real one) shows the
  shape and naming convention.
- **Major** (`0.x.y` → `1.0.0`, or any breaking bump): changes that
  restructure how configs are deployed — renaming/moving a symlinked
  directory, changing what `symlinks.sh` links where, changing the
  manifest's own row format — anything an existing install can't just
  pick up passively and needs an explicit migration for.

Pulling a version bump on an existing install: run `dots update`. It
pulls (fast-forward only) and re-runs `install-fedora.sh`, which runs
`scripts/migrate.sh` before anything else and so brings the manifest's
recorded version forward. `dots update --dry-run` shows what would come in. With
nothing to pull it still re-runs the installer when the last *finished* install
is from an older commit than the checkout — so on a 0.1.0 install, which predates
`dots update`, `git pull` then `dots update` works, and an install you stopped
partway (Ctrl-C, a failed stage) or ran one `--only-<stage>` at a time is
finished by the next `dots update`. Only a full `install-fedora.sh` run that
reaches its end counts as finished. See `docs/UNINSTALL.md`
for reversing an install entirely.
