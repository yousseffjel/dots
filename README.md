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
