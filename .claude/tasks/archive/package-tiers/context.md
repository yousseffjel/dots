# Context — package-tiers

## Background

`MASTER_PLAN.md` queue item: *"Decide which roster packages are load-bearing
enough for `core.lst`."* Raised and deferred by **five** separate sub-tasks of
the roster Epic — alacritty (3), sxhkd (4), maim/slop/xprop (5), procps-ng (6),
picom (the 2026-08-08 autostart fix) — each time into a change log the next
sub-task never read. The queue bullet asks for one pass over the whole roster
rather than a sixth follow-up line.

## Prior Decisions

- **User, this session (2026-08-08):** three tiers — `core` / `desktop` /
  `extra` — over "promote + summary" or "summary only". And a new
  `packages/build.lst` over folding build deps into `core.lst` or leaving the
  inline array documented as an exception.
- **CLAUDE.md rule 10** — package names live in `packages/*.lst`, never as
  inline arrays in installer scripts. `install-suckless.sh:84` violates this.
- **CLAUDE.md rule 4** — COPR-only packages are dropped from the lists and
  documented in a header comment, not silently attempted. `clipmenu` /
  `clipnotify` are the one authorized auto-enable; `starship` is installed from
  its upstream script and is deliberately in no `.lst`.
- **CLAUDE.md rule 8** — package names are verified against
  packages.fedoraproject.org by hand. There is no `dnf` on this Arch dev host.
- **Locked decisions 8/9/10/12** (roster scope file) — `unrar`,
  `power-profiles-daemon`, `ddcutil`/`i2c-dev`, `brightnessctl` stay out. The
  `NOT LISTED HERE` block in `extra.lst` records each with its reason and must
  survive the rewrite.

## References

- `packages/core.lst` (6 pkgs), `packages/extra.lst` (~90 pkgs + a 30-line
  `NOT LISTED HERE` header)
- `scripts/install-pkg.sh:63` `read_pkg_list()`, `:85` core loop (hard-fail),
  `:99` extra loop (best-effort), `:68` `dnf_install()`
- `scripts/install-suckless.sh:76` `install_deps()` — the inline array
- `scripts/install-fedora.sh:145` — comment already admitting
  `libxcrypt`/`ncurses` are needed but undeclared
- `tests/pkglist.sh:42,53,63` — names the two lists in three places
- `.github/workflows/ci.yml:155,165` — `hashFiles('packages/*.lst')` (already a
  glob, fine) and `for list in packages/core.lst packages/extra.lst` (not)
- `scripts/uninstall_steps.sh:140` — reads `PACKAGE` manifest rows, tier-blind

## Notes

**Findings from the inline explore (2026-08-08), all verified by grep:**

1. `install-suckless.sh:84` declares `libXext-devel`, `libXrandr-devel`,
   `libxcrypt-devel` and `ncurses` — **none appear in any `.lst`**. Five more
   (`libX11-devel`, `libXft-devel`, `libXinerama-devel`, `freetype-devel`,
   `fontconfig-devel`) are duplicated from `extra.lst`. That is both the rule 10
   violation and live drift.

2. **`procps-ng` is declared nowhere**, yet `pgrep`/`pkill`/`pidof` are called
   **unguarded** by `config/sxhkd/sxhkdrc` (every volume/mic/brightness key
   signals dwmblocks), `config/dwm/bin/dwm-powermenu`, `config/dwm/bin/dwm-lock`,
   and the `dunst.dcol` + `picom.dcol` post-commands. Fedora `@core` ships it, so
   this is a declaration gap rather than a live break.

3. **`desktop-file-utils`** (`update-desktop-database`) is likewise undeclared,
   but both call sites are `command -v` guarded — lower priority.

4. **No failure summary exists.** ~110 best-effort packages each print a green
   line; a failure is one yellow line that scrolls past. Worse, `dnf_install()`
   sends all dnf output to `/dev/null` and checks only the exit status, so a
   network blip, a GPG error and a genuine rename all print the same misleading
   `skipped (not found in enabled repos)`.

**Open design question for step 5 — where the consequence text lives.**
The failure summary should say *what dies*, not just *what failed*. Preferred:
a trailing `# ` comment on each `desktop.lst` line, since `read_pkg_list()`
already strips trailing comments, so the install path is unchanged and one
source of truth serves both readers. The new test then asserts every
`desktop.lst` entry has one — the same drift guard shape as
`tests/autostart-daemons.sh`. Alternative: a `case` map inside
`install-pkg.sh`, which splits the fact across two files and will drift.
Decide at step 3, before writing the summary.

**Sizing.** Large — ~14 files across packages/, scripts/, tests/, CI and docs.
Not Epic: it is one coherent change, and splitting it would leave the repo with
a tier the installer does not read.
