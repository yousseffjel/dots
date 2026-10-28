# Testing and CI

dots has a shell test suite, three pinned linters and two GitHub Actions workflows. The full guide, with a note on
what each notable test guards, is [TESTING.md](https://github.com/YoussefFjel/dots/blob/main/TESTING.md). This
page is the overview.

The suite is whatever `ls tests/*.sh` prints. This page does not list the tests, on purpose.

## Running it locally

```sh
tests/run-tests.sh    # the whole suite CI's tests job runs (bash + coreutils)
tests/lint.sh         # shellcheck + shfmt + markdownlint
tests/build.sh        # compile dwm/st/dmenu/dwmblocks/slock (needs packages/build.lst installed)
tests/<name>.sh       # any single test
```

These are the same invocations CI makes. The workflows call the scripts instead of restating their checks, so a
clean local run is a strong signal CI will pass.

### tests/run-tests.sh

[`tests/run-tests.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/run-tests.sh) is the single owner of
"run every test". It:

- globs `tests/*.sh` at depth 1, so a new test is picked up with no wiring;
- skips `build.sh` and `lint.sh`, which run in their own CI jobs with the tools they need;
- creates a fresh workspace (under `${XDG_CACHE_HOME:-~/.cache}/dots-tests`, overridable with
  `DOTS_TEST_TMP_ROOT`), exports it as `TMPDIR` to every test and cleans it on every exit path, refusing an unsafe
  root such as `/` or `/tmp`;
- runs the suite under `setsid`, so a Ctrl-C or a killed job cannot orphan a child process.

`tests/lib/` holds **sourced helpers**, never tests. The runner never executes them on their own, but the linter
still checks them. `tests/fixtures/` holds captured real-tool files.

### tests/lint.sh and --strict

[`tests/lint.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/lint.sh) runs shellcheck, `shfmt -d` (diff
only, never rewrites) and markdownlint over every tracked `*.sh` and `*.md` at any depth, minus what
`.markdownlintignore` and `.gitignore` exclude.

By default a missing linter is reported and skipped, so it is usable on a machine with only some tools installed.
CI passes `--strict`, which turns a skip into a failure: there the tools were just installed, so "not installed"
means the install step broke and the job would otherwise go green having checked nothing.

Formatting style is `shfmt -i 4 -ci -bn`. Markdown follows
[`.markdownlint.yaml`](https://github.com/YoussefFjel/dots/blob/main/.markdownlint.yaml) (120-column lines,
fenced code blocks with a language). The pre-commit hooks run the same three linters on each commit.

## Writing a test

The habits that matter, all from [CONTRIBUTING.md](https://github.com/YoussefFjel/dots/blob/main/CONTRIBUTING.md#test):

- **Sandbox every path.** Set `HOME` and all four `XDG_*_HOME` variables. `HOME` alone still lets the installer
  write into your real `~/.local/state/dots/manifest`, and `uninstall.sh` acts on that manifest. The symmetry
  test goes further with `env -i`.
- **Fake the desktop, not the thing under test.** Put fake `xrandr`, `pkill`, `feh`, `xbps-install` and so on
  first on `PATH`. `tests/lib/sealed-path.sh` builds a `PATH` containing only fakes plus links to the real tools
  you name, so a "not installed" case cannot fall through to a real binary and nothing reaches your screen,
  clipboard or package database.
- **Never run the theming engine's real `always/` templates outside a sandbox.** Their post-commands `pkill`
  dunst and dwmblocks system-wide. Stub `apply-templates.sh` and `reload.sh` instead.
- **Read shipped sources of truth, don't restate them.** Tests extract and run the shipped parser
  (`read_pkg_list`), read lists back from `symlinks.sh --list-links` or `dots --help`, and glob rather than name.
- **Prove the test can fail.** Break the code under test on a copy and watch it go red. A test that never failed
  has not been shown to check anything. Many test headers record their mutation results.
- **Don't supply a default the code is meant to provide.** A test that sets a value itself never tests the
  shipped default.
- **Skip loudly** (a yellow line) when a real tool the test needs is missing, and offer a `--strict` mode if a CI
  job should fail instead.

## The CI jobs

Two workflows live in [`.github/workflows/`](https://github.com/YoussefFjel/dots/tree/main/.github/workflows).

[`ci.yml`](https://github.com/YoussefFjel/dots/blob/main/.github/workflows/ci.yml) runs on every push and pull
request to `main`:

| Job | Where | What it does |
| --- | ----- | ------------ |
| `lint` | Ubuntu runner | Installs the pinned linters, then `tests/lint.sh --strict`. |
| `tests` | Ubuntu runner | Installs tmux (for one live check), then `tests/run-tests.sh`. |
| `build-suckless` | Void container | Installs `packages/build.lst`, runs `tests/build.sh`, `tests/bidi.sh --strict`, then `tests/dwm-runtime.sh` and `tests/dwm-multimon.sh` under Xvfb. |
| `package-names` | Void container | Checks every name in `packages/*.lst` and `packages/live/*.lst` against Void's live main index. |

The container jobs use `ghcr.io/void-linux/void-glibc-full:latest`, one leg each: Void is rolling, so there is no
older release to pin. The image is bare (no bash, no git), so each job starts with a plain-`sh` step that syncs,
updates xbps, upgrades and adds both. Every `xbps-install` there goes through a small retry wrapper, and the
main repository is fetched through Void's CDN mirror, because network blips on Void's side used to fail jobs no
change had touched.

Test-only tools (Xvfb, xdotool, ImageMagick, the ASan runtime) are installed in the job, never added to
`build.lst`: a real install never needs them.

### install-container

[`install-container.yml`](https://github.com/YoussefFjel/dots/blob/main/.github/workflows/install-container.yml)
is the only job that actually **runs** `scripts/install-void.sh`, fully, with no `--dry-run` and no
`--skip-suckless`, as root in the same Void image. It then asserts on what landed. Its expectations are derived
from shipped sources (the symlink set from `symlinks.sh --list-links`, binaries from the manifest's `SUCKLESS`
rows, package failures from the installer's own summary), so a new symlink or program is covered with no edit.

It is slow (a full upgrade, around a hundred packages, ly built from source), so it has a `paths:` allowlist and a
docs-only push skips it. A new top-level directory the installer reads must be added to that allowlist. It can
also be started by hand (`workflow_dispatch`).

Its assertion step is inline bash in the YAML, which `tests/lint.sh` does not lint. Extract it and shellcheck it
by hand when you edit it.

### What a container cannot prove

The job prints these limits in its own output rather than passing quietly:

- **Login shell:** the `usermod` step is asserted, but it runs as root, so the `sudo` path a real user takes is
  not proved.
- **Services:** runit service links (dbus, elogind, NetworkManager, ly) are asserted. A link is not a running
  service: whether runit brings them up, and whether ly hands off to the session, needs a VM or hardware.
- **Anything graphical:** there is no display. The suckless programs are built and installed but never run as a
  session, and the initial theme apply is skipped for want of `$DISPLAY`.

Those are VM or hardware questions. dots has been run end to end in VMs (including a matrix of UEFI/BIOS and
plain/LUKS through the live installer) but **not on bare metal**.

## Linter pins

Each linter is pinned twice: as a version in `ci.yml`'s `env` block (shellcheck also with a SHA-256 of the release
tarball) and as the matching hook `rev:` in
[`.pre-commit-config.yaml`](https://github.com/YoussefFjel/dots/blob/main/.pre-commit-config.yaml).
[`tests/linter-pins.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/linter-pins.sh) fails when a pair
disagrees, ignoring packaging suffixes such as `v0.11.0.1`.

The reason is concrete: shellcheck renumbers findings between minor releases, so a `# shellcheck disable=` line
that satisfies one version is ignored by another. Unpinned, a commit could pass locally and fail in CI.

Dependabot opens monthly PRs for action versions and hook revisions. It cannot edit `ci.yml`'s env vars, so a
linter bump stays red until you bump the twin (and `SHELLCHECK_SHA256`) on the same branch.

## Testing a full install safely

Never run `scripts/install-void.sh` on a machine you care about: it installs packages, enables Void's nonfree
repository, and changes your login shell and display manager.

For the installer's logic, use the sandboxed tests. `tests/install-uninstall-symmetry.sh` runs the restore stage
twice and `uninstall.sh --yes` once in a sandboxed `HOME`, with fakes for every system tool, and requires the home
directory to come back as it was.

For a real run, use a throwaway container from the same image CI uses:

```sh
docker run --rm -it ghcr.io/void-linux/void-glibc-full:latest sh
# inside:
xbps-install -Syu xbps && xbps-install -yu && xbps-install -y bash git
git clone https://github.com/YoussefFjel/dots.git ~/dots && cd ~/dots
bash scripts/install-void.sh --dry-run
bash scripts/install-void.sh
```

That validates packages, links and the build, not the graphical session. For the session, use a Void VM.
