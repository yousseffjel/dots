# packages-roster-fonts
Date: 2026-08-06
Files: 8 | Lines: +535/-91

Sub-task 2 of the Epic "app / tool / package roster finalization"
(`.claude/tasks/scope-b-app-roster-finalization.md`, main-side).

## What changed

- **`packages/extra.lst` — the final roster.** Added `alacritty`, `firefox`,
  `cascadia-code-nf-fonts`, `maim`, `slop`, `xss-lock`, `bluez`, `blueman`,
  `thunar-volman`, `ffmpegthumbnailer`, `unar`, `catfish`, `zoxide`,
  `fastfetch`. Removed `kitty` (superseded by alacritty, never configured).
  Each sits under the existing category comment per rule 10, with a one-line
  note saying which sub-task consumes it.
- **A "NOT LISTED HERE" header** documenting the five deliberate exclusions —
  `starship`, JetBrains Mono Nerd Font, `ddcutil`/`i2c-dev`,
  `power-profiles-daemon`, `unrar` — each with the reason and, where one
  exists, the exact command to get it anyway.
- **`scripts/install-pkg.sh` — a starship install block.** Fedora does not
  package starship, so it is installed from the upstream script. Idempotent
  (`command -v starship` guard), dry-run aware, and best-effort: on failure it
  warns and the run continues to `✓ package stage complete`.
- **`config/starship/starship.toml` — adopted the user's real config**,
  replacing the 103-line ASCII placeholder shipped by sub-task 1. The `󰣇` Arch
  logo became Fedora's `` (U+F30A), and 44 of 59 `[section]` blocks were
  dropped along with their `right_format` entries (see Assumptions).

## Why

Two problems drove the shape of this.

**starship is not in Fedora's repos.** Verified 2026-08-06: zero results across
F43/44/Rawhide and every EPEL. It was dropped around F37 and now lives in the
`atim/starship` COPR. That is not cosmetic — sub-task 1 made starship *the*
prompt, so on a fresh Fedora box the `(( $+commands[starship] ))` guard in
`99-prompt.zsh` fails, the shell falls back to `prompt adam1`, and the adopted
config sits unused. The user chose the upstream install script over the COPR
with the trade-offs stated: it pipes a remote script to a shell and installs
outside dnf, so dnf can neither upgrade nor remove it.

**The repo shipped a prompt config worse than the user's own.** Sub-task 1
placed a 103-line ASCII placeholder at `config/starship/starship.toml`, and
`symlinks.sh` would have backed up the user's hand-tuned 405-line config and
replaced it. `fc-list` then showed 135 Nerd Font matches installed, which
settled the font question the roster survey had left open: the glyphs the
prompt (and `eza --icons`, and fastfetch) depend on were never packaged, so a
fresh install would render tofu.

## Assumptions

- **Type B — `cascadia-code-nf-fonts` alone, not "both Nerd Fonts".** Fedora
  packages no JetBrains Mono Nerd variant; the `jetbrains-mono-fonts` source
  yields only `-all` and `-nl`, neither with nerd glyphs, and Cascadia is the
  only `-nf-fonts` family in the distro. Cascadia supplies every glyph and the
  existing `jetbrains-mono-fonts-all` stays for plain UI surfaces, which need
  none. Stated in-thread; no objection. If incorrect: package a Nerd Font from
  a COPR or vendor one under a new `fonts/` directory.
- **Type A, escalated to the user — the 250-line cap.** The adopted config was
  420 lines against `file-architecture.md`'s hard stop. `split-oversized-file`
  cannot apply: starship has no include/import/extends directive (verified
  against starship.rs/config), so configuration cannot span files and the real
  choice was adopt-vs-don't. The user chose to drop sections for toolchains the
  repo neither declares nor installs: 44 of 59 removed, file now 151 lines.
  Their `right_format` entries went too — leaving a `$module` whose `[section]`
  is gone would let starship fall back to its default glyph-heavy rendering if
  that toolchain ever appeared.
- **Type B — no manifest row for starship.** A `PACKAGE` row would be actively
  harmful; see Follow-ups.
- **Type C — `unar` confirmed present**, so locked decision 8 holds and RAR
  support needs no RPM Fusion.

## Test coverage

- `tests/lint.sh` — shellcheck, shfmt, markdownlint all ok. It caught one real
  shfmt violation mid-task (the repo uses `-bn`, binary operators at line
  start), which was fixed.
- `tests/pkglist.sh` — format, duplicates, core/extra overlap all ok. This one
  carries real weight here: every token surviving `extra.lst`'s
  comment-stripping is handed to `dnf install`, so it guards the new 20-line
  prose header. Separately verified by parsing the file exactly as
  `read_pkg_list` does — 89 well-formed tokens, no prose leaked, `starship`
  correctly absent.
- **Package names:** 16 checked against packages.fedoraproject.org (no `dnf` on
  this Arch dev host, so rule 8 meant real lookups, not inference from Arch
  names). 14 confirmed in F43/44/Rawhide; `starship` and a JetBrains Mono Nerd
  Font do not exist.
- **The starship block, all three branches, by execution** — sandbox with
  stubbed `dnf`/`sudo`/`rpm` and a `/usr/bin` mirror omitting `starship` and
  `curl` so `command -v` genuinely fails. Already-installed short-circuits;
  dry-run reports and touches nothing; curl-absent warns and the stage still
  completes. All four XDG vars overridden per the `installer-test-sandbox-xdg`
  memory, and the real manifest verified clean afterwards.
- **The trim changed nothing:** right-prompt output is byte-identical to the
  original 405-line config in a directory carrying markers for every kept
  language.
- **Prompt cost measured, not assumed:** 3.7 ms plain, 8.4 ms in a git repo.
  Trimming `right_format` buys ~1.9 ms; `git_status` alone costs ~4.7 ms, about
  2.5x what all sixty language modules cost together. The planning-stage worry
  that `right_format` conflicted with the performance constraint is retracted.
- **`tests/build.sh` not run** — compiles the vendored suckless C tree,
  untouched here, and needs Fedora build dependencies absent from this host.
- **Not covered:** that the packages actually install. That needs real Fedora
  hardware; CI's `install-dry-run` job validates names against live repos, and
  CLAUDE.md already tracks the end-to-end run as open.

## Follow-ups

- **Terminal and bar fonts do not point at the Nerd Font.** `dwm` and `dmenu`
  use `monospace:size=10` (resolves to DejaVu Sans Mono here) and `st` uses
  `Liberation Mono`. Installing `cascadia-code-nf-fonts` does not change that —
  glyphs render through fontconfig's per-glyph fallback, which works but gives
  mismatched glyph metrics. Setting the font explicitly belongs to **sub-task
  3** (alacritty) and **sub-task 7** (dwm/statusbar); `suckless/` was Forbidden
  in this plan.
- **`uninstall.sh` cannot remove starship.** No manifest row is written, and
  deliberately so: `uninstall_packages()` pipes every `PACKAGE` value into a
  single `dnf remove`, so one un-removable name would fail that call and leave
  every other package installed. A `SCRIPT` row would delete correctly but file
  starship under a prompt reading "dwmblocks block scripts". The clean fix is a
  new `BIN` manifest category plus a handler in `uninstall_steps.sh` — both
  outside this plan's Allowed. Manual removal is documented in the installer:
  `rm -f ~/.local/bin/starship`.
- **starship is not dnf-upgradable.** `starship upgrade` or a re-run of the
  install script is the update path.
- Sub-task 9's theming template must rewrite hardcoded hex literals
  (`#8be9fd`, `#769ff0`, `#394260`, `#a0a9cb`, `#9198a1`) — the adopted config
  has no `[palettes]` table to swap, unlike the placeholder it replaced.
