# tmux-terminfo
Date: 2026-10-27
Files: 5 | Lines: ~+110/-3 (config, package list, new test, CHANGELOG; plus this log)

## What changed
- `packages/extra.lst`: `ncurses-term`, next to `tmux`. It is in Void's main
  repo and is the package holding `/usr/share/terminfo/t/tmux-256color`
  (`xbps-query -R -f ncurses-term`, run on the Void dev host; rule 8).
- `config/tmux/conf.d/00-options.conf`: an `if-shell` fallback to
  `screen-256color` (ncurses-base) when `infocmp tmux-256color` fails, so an
  install from before this change works after a tmux server restart, without
  waiting for a re-run.
- The same file's `terminal-features` line was malformed:
  `",xterm-kitty:RGB,clipboard,sync,title,hyperlinks,osc7"` gives tmux six
  entries, with `clipboard`, `sync` and the rest as terminal NAMES, so
  kitty got RGB only (shown with `show -g terminal-features` on tmux 3.8).
  Each terminal is now one entry with its features joined by `:`. alacritty,
  the main terminal, had no entry at all, so it got no true colour inside tmux.
  It now has RGB, clipboard, sync, title and hyperlinks. The `xterm-kitty:Tc`
  override is gone; its RGB feature covers it.
- `tests/tmux-terminal.sh` (new): a real isolated tmux server against a
  terminfo dir with and without `tmux-256color` (copies of screen-256color made
  with tic), and the features list checked for bare feature names.
  Mutation-checked: the old line and no fallback fail three checks.

## Why
The user's screenshot (alacritty → tmux → zsh on the Void dev host): each
redrawn prompt line kept the tail of the previous one. TERM=tmux-256color had
no terminfo entry, so zle had no `el` (clear to end of line).

## Assumptions
- Type B: `extra.lst`, the same tier as `tmux` itself; a missing tmux makes
  the terminfo moot.

## Test coverage
- `tests/tmux-terminal.sh` 5 checks, pass; pkglist, void-pkgnames, pkg-tiers,
  uninstall-packages pass. shellcheck/shfmt clean.

## Follow-ups
- An existing tmux server keeps its old default-terminal until
  `tmux kill-server` (or install ncurses-term and restart it).
