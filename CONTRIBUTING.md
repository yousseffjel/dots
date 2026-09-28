# Contributing

dots is a personal dotfiles repo, but it is built to be changed safely. The
installer runs on someone's real machine and the uninstaller deletes files, so
most of what follows is about not breaking either.

This file is deliberately short and points at where each rule lives, rather
than restating them. Every hand-copied list in this repo has eventually gone
stale, so each fact is kept in one place and linked from the others.

## Before you change anything

- **Fedora only.** `scripts/install-fedora.sh` is the one supported installer.
  Package names are Fedora/dnf names.
- **Read `CLAUDE.md`'s "Project-specific rules".** It is written for an AI
  assistant, but those ten rules are the repo's conventions, and the numbers
  below refer to them.
- **Check `.claude/tasks/MASTER_PLAN.md`** for what is queued or deferred. Some
  things are absent on purpose (a static `.Xresources`, a `config/fastfetch/`
  directory), and `CLAUDE.md` explains why.

## Set up

```sh
pip install pre-commit      # or: pipx install pre-commit
pre-commit install          # shellcheck, shfmt, markdownlint + whitespace/shebang checks, per commit
```

## Test

`TESTING.md` is the full guide. The short version:

```sh
tests/run-tests.sh          # the suite CI runs (bash + coreutils only)
tests/lint.sh               # shellcheck + shfmt + markdownlint
tests/build.sh              # builds the suckless programs (needs build.lst's packages)
```

When you write a test:

- It goes in `tests/<name>.sh`, and CI picks it up automatically. Sourced
  helpers go in `tests/lib/`, which is never run as a test.
- **Sandbox every path it writes.** Set `HOME` **and** all four `XDG_*_HOME`
  variables. `HOME` alone lets the installer write into your real
  `~/.local/state/dots/manifest`, and `uninstall.sh` acts on that manifest.
- **Fake the desktop, not the thing under test.** Put fake `xrandr`, `pkill`
  or `feh` scripts first on `PATH`, rather than running scripts against your
  live session. Never run the theming engine's `always/` templates outside a
  sandbox: their post-commands `pkill` dunst and dwmblocks system-wide.
- **Prove the test can fail.** Break the code under test on a *copy* and
  confirm the test goes red. A test that has never failed has not been shown
  to check anything.

## Conventions

| Area | Rule | Where it is enforced or explained |
| ---- | ---- | --------------------------------- |
| Every script | idempotent, `set -euo pipefail`, own colour helpers, `SCRIPT_DIR`/`DOTS_DIR` | `CLAUDE.md` rules 1–3 |
| Size | 250 lines per file, 60 per function; split, don't grow | a sourced `*-<part>.sh` sibling, as in `scripts/install-session-*.sh` |
| Packages | names only in `packages/*.lst`; pick the tier by what breaks | `CLAUDE.md` rule 10, `tests/pkglist.sh` |
| Package names | checked against packages.fedoraproject.org, never guessed | `CLAUDE.md` rule 8 |
| Third-party repos | never enabled by default | `CLAUDE.md` rule 4 |
| suckless | change the sources **and** the `.diff` + `PATCHES.md` record together | `CLAUDE.md` rule 5 |
| Autostart | a new daemon is a three-place change | `CLAUDE.md` rule 6, `tests/autostart-daemons.sh` |
| Configs | directories are symlinked; files the apps rewrite (dunst, picom, Thunar, mime) are copied | `CLAUDE.md` rule 7, `docs/THEMING.md` |
| Installer output | anything created must get a manifest row, or uninstall cannot remove it | `scripts/global_fn.sh` (`manifest_*`) |

## Record the change

- Add a line under `## [Unreleased]` in `CHANGELOG.md` for anything a user
  would notice.
- The reasoning belongs in a dated log under `.claude/changes/`, not in the
  changelog.

## Cut a release

1. Decide the bump using `README.md` under **Versioning**.
2. If an existing install needs a step to reach the new version, add
   `scripts/migrations/<old>-to-<new>.sh`, following the template in that
   directory.
3. Rename `## [Unreleased]` to `## [<new>] - <YYYY-MM-DD>`, then add a fresh
   empty `## [Unreleased]` above it.
4. Bump `VERSION` to `<new>`. `tests/changelog-version.sh` fails until steps 3
   and 4 agree.
5. Tag it with `git tag v<new>`.
