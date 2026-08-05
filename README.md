# dots

[![CI](https://github.com/yousseffjel/dots/actions/workflows/ci.yml/badge.svg)](https://github.com/yousseffjel/dots/actions/workflows/ci.yml)

Personal dotfiles + a suckless-based dwm/X11 desktop bootstrap for Fedora.
See `CLAUDE.md` for the full project map and installer usage.

## Development

This repo lints shell scripts (shellcheck + shfmt), Markdown
(markdownlint), and validates the suckless build + package lists in CI —
see `.github/workflows/ci.yml` and `TESTING.md`.

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

This repo follows semver via the `VERSION` file at the repo root.
`scripts/version.sh` prints the repo version alongside what's actually
installed (read from the manifest at `~/.local/state/dots/manifest`,
written by `install-fedora.sh`).

- **Patch** (`0.1.0` → `0.1.1`): fixes, package-list corrections, or
  anything that doesn't change what `install-fedora.sh` deploys or how —
  nothing on an existing install needs to change to pick it up.
- **Minor** (`0.1.0` → `0.2.0`): additive, backward-compatible changes — a
  new config file gets symlinked, a new suckless patch, a new optional
  package — that may still need a migration step on an existing install
  (e.g. seeding a new directory). Add a
  `scripts/migrations/<from>-to-<to>.sh` script whenever a minor bump
  needs one; see `scripts/migrations/0.1.0-to-0.2.0.sh` for the template
  and naming convention.
- **Major** (`0.x.y` → `1.0.0`, or any breaking bump): changes that
  restructure how configs are deployed — renaming/moving a symlinked
  directory, changing what `symlinks.sh` links where, changing the
  manifest's own row format — anything an existing install can't just
  pick up passively and needs an explicit migration for.

Pulling a version bump on an existing install: run `scripts/migrate.sh`
(or just re-run `install-fedora.sh`, which calls it automatically) to
bring the manifest's recorded version forward. See `docs/UNINSTALL.md`
for reversing an install entirely.
