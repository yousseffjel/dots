# Contributing

dots is a personal repo, but it is built to be changed safely. The installer runs on real machines and the
uninstaller deletes files, so most of the rules below exist to keep either from going wrong.

[CONTRIBUTING.md](https://github.com/YoussefFjel/dots/blob/main/CONTRIBUTING.md) in the repo is authoritative;
this page is a practical companion. The full set of conventions is the "Project-specific rules" section of
[CLAUDE.md](https://github.com/YoussefFjel/dots/blob/main/CLAUDE.md).

## Workflow

1. **Branch.** Don't commit straight to `main`.
2. **Install the hooks once**, so every commit runs shellcheck, shfmt, markdownlint and whitespace checks:

   ```sh
   pip install pre-commit    # or: pipx install pre-commit
   pre-commit install
   pre-commit run --all-files
   ```

3. **Make the change**, following the rules below.
4. **Test.** At minimum `tests/run-tests.sh` and `tests/lint.sh`; `tests/build.sh` if you touched `suckless/`.
   Write a new test for new behaviour, and prove it can fail. See [Testing and CI](Testing-and-CI).
5. **Record it.** A line under `## [Unreleased]` in
   [CHANGELOG.md](https://github.com/YoussefFjel/dots/blob/main/CHANGELOG.md) for anything a user would notice.
   The reasoning (what you tried, how you verified it) goes in a dated log under `.claude/changes/`, not in the
   changelog.

## When you do X, also do Y

### Writing or editing any script

- Start with `set -euo pipefail`. Every script must be **idempotent**: a second run after a partial or full
  success is a safe no-op or converges to the same state. Never duplicate work or fail because something
  already exists.
- Define the four colour helpers and use them instead of raw `echo`: red for hard errors, green for success or
  "already ok", yellow for warnings and manual follow-ups, blue for information.

  ```bash
  red() { printf '\033[31m%s\033[0m\n' "$*"; }
  green() { printf '\033[32m%s\033[0m\n' "$*"; }
  yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
  blue() { printf '\033[34m%s\033[0m\n' "$*"; }
  ```

- Find yourself and the repo the same way every script does. Never hardcode paths.

  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  ```

  The exception is `scripts/dots`, reached through a symlink, which uses `readlink -f`.
- Support `--dry-run` wherever the script changes anything, and check `DRY_RUN` in every new mutating step.
- Format with `shfmt -i 4 -ci -bn` (the pre-commit hook does it).

### When a file or function gets long

The caps are **250 lines per file and 60 lines per function**. Split, don't grow: move a coherent part into a
sourced sibling named `<script>-<part>.sh`, as `install-session-*.sh`, `install-restore-*.sh` and
`doctor-*.sh` already do. A sourced file states in its header what it assumes the caller has set up. These
caps are a convention, not something a test enforces, so reviewers are the check.

### Creating anything on the user's system

Give it a manifest row (`manifest_append_row` in
[`scripts/global_fn.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/global_fn.sh)) and an uninstall
step, in the same change. Write the row only when this run created the thing; never claim a file the user
already had. See [Architecture](Architecture#the-install-manifest).

### Adding a config directory

- If the program only **reads** its config, add it to `LINKS` in
  [`scripts/symlinks.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/symlinks.sh). Link
  directories, not single files; `symlinks.sh` backs up conflicts before linking.
- If the program, GIO or the theming engine **writes** to it, copy it from the restore stage instead and claim
  it in the manifest. Never link it.

### Adding a package

Names go in `packages/*.lst` only, never as an inline array in a script. Pick the tier by what breaks without
it, use a name from Void's **main** repository, and check it with `tests/void-pkgnames.sh`. See
[Packages](Packages).

Never enable a repository beyond Void's main one by default. The two the user has authorised (Flathub, per user,
and Void's nonfree repo for the default editor) each get a manifest row only when this run added them. If
something exists only elsewhere, leave it out of the lists, say in a header comment how to get it, and print a
yellow reminder. Vendoring a self-contained, checksummed artifact under `assets/` is the other option; never
vendor anything that needs building.

### Changing a suckless program

Edit the source **and** its `.diff` record and `PATCHES.md` entry in the same commit. See
[Suckless and Patches](Suckless-and-Patches).

### Adding an autostart daemon

It is a three-place change, enforced by a test. See [Session and Autostart](Session-and-Autostart).

### Adding a theming template

Read
[config/theme/templates/always/README.md](https://github.com/YoussefFjel/dots/blob/main/config/theme/templates/always/README.md)
first. See [Theming Engine](Theming-Engine).

### Adding a `dots` subcommand

One line in the `SUBCOMMANDS` array in [`scripts/dots`](https://github.com/YoussefFjel/dots/blob/main/scripts/dots).
Help, completion and tests read it from there.

## Never restate a list

Every hand-copied list in this repo has eventually gone stale. Each list lives in one place, and everything else
reads it back or points at it:

| List | Its one home | How to see it |
| ---- | ------------ | ------------- |
| `dots` subcommands | `SUBCOMMANDS` in `scripts/dots` | `dots --help` |
| Tests | `tests/*.sh` | `ls tests/*.sh` |
| Packages | `packages/*.lst` | the files |
| Suckless patches | `suckless/*/patches/` | `ls suckless/*/patches/*.diff` |
| Symlinked configs | `LINKS` in `scripts/symlinks.sh` | `scripts/symlinks.sh --list-links` |
| Autostart daemons | the `session_autostart_*` template parts | `tests/autostart-daemons.sh` |
| Manifest row kinds | the `manifest_append_row` calls | `grep -rn manifest_append_row scripts/` |

Consumers glob rather than name: tests and CI glob `packages/*.lst` and `tests/*.sh`, so a new list or test is
covered without wiring. Do the same in new code.

## Releases

The steps are in [CONTRIBUTING.md](https://github.com/YoussefFjel/dots/blob/main/CONTRIBUTING.md#cut-a-release).
In short: decide the bump (README's **Versioning**), add `scripts/migrations/<old>-to-<new>.sh` even when
there is nothing to migrate (a no-op that says why), rename `[Unreleased]` to the new version, bump `VERSION`,
and tag. `tests/migration-current.sh` and `tests/changelog-version.sh` fail until those agree.

## Keeping pins current

Dependabot bumps GitHub Actions and the pre-commit hook revisions monthly. A linter bump stays red on
`tests/linter-pins.sh` until the matching version in `ci.yml`'s env block is bumped on the same branch (plus
`SHELLCHECK_SHA256` for shellcheck). The Void package-index snapshot and the vendored suckless sources are
refreshed by hand.

## Don'ts worth remembering

- Don't add a static `.Xresources`; the theming engine generates it.
- Don't add `config/fastfetch/` or `config/gtk-3.0/`; their templates are the only authored copies.
- Don't add `config/dunst` or `config/picom` to `symlinks.sh`.
- Don't bind a key in both dwm's `config.def.h` and `config/sxhkd/sxhkdrc`; a doubly grabbed key silently dies.
- Don't add a build-time patch step for the suckless sources.
- Don't move the theme restore from `~/.xinitrc` into `autostart.sh`.
