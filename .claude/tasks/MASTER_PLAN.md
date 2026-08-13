# MASTER_PLAN — dots

Last Updated: 2026-08-12

Strategic roadmap. One task per slot; multiple `## Active` entries allowed
when slots run concurrently.

---

## Active

*(none — Epic scope-c closed 2026-08-12; see Recently Closed)*

---

## Queue

- **`@resurrect-dir` in `config/tmux/conf.d/30-plugins.conf` hardcodes
  `$HOME/.local/state`,** ignoring `$XDG_STATE_HOME`. Exactly the class of bug
  the 2026-08-10 sweep fixed for `$XDG_DATA_HOME`/TPM, one variable over. It
  is a `set -g @resurrect-dir` option string with no shell, so it needs the
  same single-quoted `run-shell` treatment the TPM paths got — see the header
  of that file for why double quotes reintroduce the bug.
- **Watch the first CI run after 2026-08-10.** The `lint` and `build-suckless`
  jobs were rewired to invoke `tests/lint.sh --strict` and `tests/build.sh`
  without CI ever executing once. Two things are unproven: that
  `npm install -g` works without sudo on a GitHub-hosted runner, and that
  shfmt on `$GITHUB_PATH` is visible to `lint.sh`'s `command -v`. Both fail
  loudly rather than silently (`--strict` is what guarantees that), but they
  have not been observed.
- **Run `install-fedora.sh` end-to-end on real hardware.** Still never
  done; package names are verified against upstream repos, not live. The
  whole roster Epic was verified in sandboxed `$HOME` trees and against
  local binaries on an **Arch** dev host — never on a Fedora box.

### Framework parity with HyDE (opened 2026-08-12 by a fresh HyDE diff)

Source: comparison against the local HyDE clone at `8fa0073e` (2026-08-01),
inspected directly rather than from `ROADMAP.md`. These are the **structural**
gaps; the desktop-feature gaps from the same pass (tray applets, bluetooth
service, volume/brightness OSD, battery, network block, screen recorder,
`.gtkrc-2.0`, blue-light filter, emoji picker, keybind hint) were reviewed at
the same time and **not** queued — raise them separately if wanted.

- **A container harness that runs `install-fedora.sh` for real.** HyDE ships
  `Scripts/hydevm`; `TESTING.md` currently tells a human to drive `toolbox` by
  hand, which is why the real-hardware item above has sat open since
  2026-08-04. Acceptance is not "a script exists" — it is that the harness
  runs the installer to completion in a `fedora:latest` container and asserts
  on the result, so the failure mode it catches is a wrong package name or a
  stage that aborts, not a lint error. Note the two things a container
  genuinely cannot cover (`chsh`, `systemctl enable ly.service`) and make it
  say so rather than skipping them silently. Closest existing prior art in
  this repo is the `install-dry-run` CI job, which proves only that the
  orchestrator threads its flags.
- **A single user-facing command on `$PATH`.** HyDE has `hydectl` /
  `hyde-shell`. dots has 21 scripts under `scripts/` — none on `$PATH` — plus
  9 in `config/dwm/bin/`, which is the only directory `.zshenv` adds. The
  question to settle before writing anything is whether this is a real
  dispatcher (`dots theme|wallpaper|version|uninstall`) or just a symlink of
  the four user-facing entry points into `~/.local/bin`. Note the shadowing
  hazard already recorded in memory: `~/.local/bin` wins over
  `~/.config/dwm/bin`, and `dwmblocks`' scripts already live in the former.
- **Font and cursor assets that Fedora does not package.** HyDE's
  `restore_fnt.sh` extracts tarballs into `~/.local/share/{fonts,icons}` and
  runs `fc-cache`. dots is repo-packages-only, which is exactly why
  `bibata-cursor-themes` was dropped as COPR-only and `themes/dark/theme.conf`
  fell back to `cursor_theme=Adwaita`. Any implementation must go through the
  manifest (`manifest_append_row`) or `uninstall.sh` cannot remove what it
  drops, and downloading from GitHub releases at install time is a trust
  decision of the same class as rule 4's COPR default — ask first.
- **`CHANGELOG.md` + `CONTRIBUTING.md`.** `VERSION`, `version.sh` and
  `scripts/migrations/` all exist, so the repo versions itself but tells a
  user nothing about what changed between versions. The `pr-notes` skill
  generates this directly from `.claude/changes/` — the work is choosing what
  a release boundary *is* here, not writing prose.
- **Dependency automation for the pins.** HyDE runs `renovate.json5`. dots
  hand-bumps `fedora:43` in two `ci.yml` matrices (done once already,
  2026-08-12) and vendors 23 suckless `.diff` files that no tool watches.
  Renovate covers the container tags; nothing covers the patches. Worth
  scoping as "what can actually be automated here" before adopting a tool —
  the answer may be one Dependabot stanza and a documented manual patch sweep.

---

## Recently Closed

- 2026-08-12 — **theme roster 1 → 4 + `theme.conf` identity wiring** —
  `60134a0`, `fb9f075`. Closes the parity queue item "More than one theme under
  `themes/`". `gruvbox`, `nord`, `tokyo-night`, every `colors.dcol` **generated**
  by `colorgen.sh` from a recorded seed hex and confirmed to regenerate
  byte-identical. The wallpaper question that item asked to settle first was
  settled: **a theme carries no `wallpapers/`** (Type C, per
  `themes/dark/wallpapers/README.md`). Scope grew beyond colours because
  `theme.conf` was report-only — a switch now applies GTK/icon/cursor/font
  identity through the installer's own writers, never clobbering a file the
  manifest does not claim. `tests/theme-identity.sh` (suite 12 → 13), 9/9
  mutations caught. Two lessons: **a test that supplies a default never tests
  it**, and **the stale doc is the sibling you did not create**.

- 2026-08-12 — **CI off the EOL Fedora pin** — `6156aa6`, `6e840d7`. Both
  matrices `fedora:41` -> `fedora:43` (oldest supported), with a comment saying
  the pin must be bumped rather than deleted. The queue entry's own rationale
  was wrong and the audit caught it being copied into the code: an EOL image
  does not vanish, its repos move to archive mirrors and `dnf` breaks while the
  image still pulls. Tag existence verified against Docker Hub before shipping.

- 2026-08-12 — **first tests for `config/dwm/bin/`** — `67d417f`, `9849c6d`.
  Nine scripts, zero tests, until `dwm-colorpicker.sh` (12 assertions) and
  `dwm-display.sh` (20). Suite 10 → 12, both picked up by CI's glob for free.
  **12 of 13 deliberate mutations fail the suite** — that measurement, not the
  assertion count, is what makes them load-bearing. The one survivor is
  documented in the test header rather than papered over. Two lessons:
  ImageMagick is deliberately NOT faked (faking the thing under test leaves the
  file asserting against its own fixture generator), so it skips **loudly**
  where CI cannot provide it; and **mutation testing only covers the mutations
  you imagine** — the reviewer found a `--primary` gap because every mutant I
  wrote attacked logic I had just authored. Seven `dwm-*` scripts remain
  untested; `dwm-brightness` is the highest-value next, as it parses
  `xrandr --verbose` and does arithmetic on it.

- 2026-08-12 — **Epic: roster gap-fill (scope-c) — ALL 4 SUB-TASKS MERGED.**
  Scope file `.claude/tasks/scope-c-roster-gap-fill.md` holds the locked
  decisions; do not re-litigate them.
  - [x] 1. packages — folded into whichever sub-task needed each one
  - [x] 2. xsettingsd — `92eb216`, `ad3c872`
  - [x] 3. udiskie + autorandr — `6b8649e`, `a011220`
  - [x] 4. dwm-colorpicker + dwm-display + ROADMAP reconciliation — `f88d684`,
        `b03573a`
  Three things from this Epic worth carrying: a tool's justification was
  **wrong** and got corrected mid-Epic before any code was written (xsettingsd);
  a **shim that matched a tool's interface but not its output format** made a
  broken script's test green until the reviewer blocked it (colour picker); and
  **enumerated lists went stale three separate times** — the daemon list, rule 6
  itself, and CLAUDE.md's `20-path.zsh` reference.

- 2026-08-12 — **Epic scope-c sub-task 3: udiskie + autorandr** — `6b8649e`,
  `a011220`. Daemons 7 → 9. Two structural splits, both cap-forced: the
  function (57/60) as planned, then the whole file (254/250) into
  `install-session-template.sh`. Three things worth carrying forward: the
  function split was proven equivalent by **byte diff**, which caught two
  defects the green test missed; a stale daemon **enumeration** was removed
  rather than extended, and CLAUDE.md rule 6 now forbids re-adding one; and the
  reviewer caught CLAUDE.md contradicting its own diff because rule 6 was
  written before the late split moved the functions it named.

- 2026-08-12 — **Epic scope-c sub-task 2: xsettingsd** — `92eb216`, `ad3c872`.
  GTK apps now get the theme identity and the Xft rendering keys from one place;
  `reload.sh` gained a 7th target and the daemon set went 6 → 7. Two things
  worth carrying forward: the tool's original justification was **wrong** (the
  "GTK apps keep a stale theme" hole does not exist — `gtk.dcol` already
  documented that GTK re-reads `gtk.css` itself), corrected in the scope file
  and `docs/THEMING.md` before building; and hoisting `theme_conf_get` nearly
  promoted a **fourth** `sed | head -1` SIGPIPE site into shared use.
  `install-restore-theme.sh` hit 286/250 and split into
  `install-restore-theme-identity.sh` (193 + 121).

- 2026-08-12 — **queue items 1 and 2, one closed by being subsumed** —
  `a48de6b`, `59d54d5`. `manifest_has_path <TAG> <path>` now lives in
  `global_fn.sh` and replaces `theme_is_ours` / `theme_backed_up` /
  `app_is_ours`; `install-restore-theme.sh` 248 → **223**, so item 1's split is
  no longer needed — exactly the subsumption item 2 predicted. Direct calls
  beat wrappers on measurement. New `tests/manifest-has-path.sh` (suite 9 → 10)
  proves the regression rather than describing it: shipped shape **5/5** on a
  200k-row manifest, the replaced `| grep -qxF` pipeline **0/5**. Two
  shellcheck findings were real — SC2329 (a test that sources `global_fn.sh`
  must not define its own colour helpers; they are overwritten and become dead
  code) and SC2015 (`cmd && pass || fail` runs both if `pass` fails). Zero
  suppressions. **The post-merge check caught `tests/build.sh` failing on main**
  from a pre-xresources `suckless/slock/config.h` — a gitignored artifact, so
  invisible to both CI and the slot worktree; all five cleared. **This log was
  also misdated `2026-08-10` and renamed with the user's approval** rather than
  self-excepting session-protocol.md's immutability clause.

- 2026-08-10 — **queue items 1–5, closed in one sweep** — `6a0c123`,
  `a47174d`. `install-session.sh` 250 → 192 via a new
  `install-session-report.sh`; CI now *invokes* `tests/lint.sh --strict` and
  `tests/build.sh` rather than reimplementing them; the third and last known
  `pipefail`/SIGPIPE site fixed (old shape reproduced at 0/5, new at 5/5);
  `xrdb -merge` bounded at 10s. The fifth item was **not** the one-line fix it
  was written as — `30-plugins.conf` hardcoded the TPM path in four more
  places, so fixing only the installer would have produced two plugin trees
  instead of one wrong path. Both sides changed together, verified against a
  real tmux 3.7b server, and `tests/tmux-tpm-lockstep.sh` now guards the
  coupling (4 mutants, all caught). Suite 8 → 9. **The queue entry described a
  symptom, not a specification** — worth remembering for the rest of this list.

- 2026-08-08 — **polkit autostart + keybound apps re-tiered** — `51a728d`,
  `24f77fc`. Closed two queue items at once. The polkit agent is launched from
  `autostart.sh` by absolute path (its binary is not on `PATH`, so the
  `command -v` pattern the other five daemons use would have silently never
  fired). `thunar` and `firefox` moved to `desktop.lst` — a **DECISION
  REVERSAL** of `package-tiers`, decided on the criterion written in
  `desktop.lst` rather than the unwritten one I had applied. Adding a sixth
  daemon broke the 60-line cap twice, forcing two provably output-identical
  refactors, and `tests/autostart-daemons.sh` was rewritten to RUN both
  functions rather than parse them.

- 2026-08-08 — **package tiers** — `5a4e681`, `13b6902`. The `core.lst` vs
  `extra.lst` review, five sub-tasks deep. Answer was not a promotion list:
  the two-tier model could not express "serious but must not abort", so
  everything load-bearing sat in best-effort `extra.lst`. Now four tiers
  (`core` 2 / `build` 13 / `desktop` 26 / `extra` 61) plus a closing failure
  summary that names each casualty and what it costs. `core.lst` *shrank* to
  `git`+`zsh` — a hard-fail on a hand-checked name would turn a degraded
  install into none. Six previously-undeclared packages now declared, the
  rule 10 inline-array violation closed, and both `tests/pkglist.sh` and
  `ci.yml` now glob the lists so a fifth tier needs no code change.

- 2026-08-08 — **picom autostart** — `592abb3`. picom added to the
  `autostart.sh` template (first, before the other four daemons) plus a
  matching branch in `session_autostart_report()`; `tests/autostart-daemons.sh`
  now pairs the two daemon sets so the same drift cannot recur. Fixed a
  pre-existing 60-line-cap violation in `install_session_autostart()` in
  passing. **Existing installs still need the line pasted by hand** —
  `autostart.sh` is user-owned (CLAUDE.md rule 6), so the installer only
  reports it.

- 2026-08-07 — **Epic: app / tool / package roster finalization**, all 11
  sub-tasks merged. Scope file:
  `.claude/tasks/scope-b-app-roster-finalization.md` (locked decisions live
  there — do not re-litigate them).
  - [x] 1. zsh: purge HyDE leftovers, retarget at dwm/X11 (+ starship.toml, zoxide) — `97b41b9`
  - [x] 2. `packages/*.lst` final roster + starship adoption + Nerd Font — `1129cf9`
  - [x] 3. alacritty as main terminal (st retained as fallback) — `f5f148a`
  - [x] 4. sxhkd keybind split with dwm — `b8a17e0`
  - [x] 5. screenshot — maim + slop + dmenu mode menu — `b2dcb13`
  - [x] 6. lock / idle — xss-lock + xset + slock — `4ebf84b`
  - [x] 7. status bar blocks — Layout A, 10 blocks + tray (order locked) — `d2a2c57`
  - [x] 8. thunar finalization (archives, thumbnails, defaults, terminal) — `b11fd73`
  - [x] 9. fastfetch + starship theming + cava removal + docs — `d3fa7f1`
  - [x] 10. picom performance tuning (template + base config in lockstep) — `f4a44aa`
  - [x] 11. dynamic scratchpads — dwm patch swap — `9202bfb`

- 2026-08-06 — **Epic: dark-mode-only theming engine (wallbash-for-X11)**,
  all 7 sub-tasks merged. Wallpaper -> ImageMagick colour extraction ->
  dcol palette -> template engine -> live targets (dwm/st/dmenu/slock/
  dwmblocks/dunst/picom/gtk/vim/cava) -> atomic reload. Dark mode only.
  Scope file: `.claude/tasks/scope-a-theming-engine.md`.
  - [x] 1. xresources patches (dwm/st/dmenu/slock) — commit `1f43276`
  - [x] 2. colorgen.sh (ImageMagick dark-mode dcol extraction) — `b98dde8`
  - [x] 3. apply-templates.sh (template engine) — commit `1d57148`
  - [x] 4. templates + base dunstrc/picom.conf — commit `27b2e40`
  - [x] 5. reload.sh (atomic ordered reload) — commit `5e79ceb`
  - [x] 6. wallpaper.sh / theme-apply.sh + keybinds — commit `f85bb8a`
  - [x] 7. static dark theme + packaging + docs — commit `ff1ca5c`
- 2026-08-06 — vim + cava app templates (post-Epic follow-up) — `399c412`
- 2026-08-05 — uninstall/versioning/migrations subsystem (VERSION,
  scripts/version.sh, global_fn.sh, uninstall.sh, migrations framework)
- 2026-08-05 — CI tooling (shellcheck/shfmt/markdownlint, pre-commit,
  GitHub Actions, tests/)
- 2026-08-05 — post-push verification audit (3 parallel read-only audits,
  bugs found and fixed in version.sh/install-restore.sh/.shellcheckrc)

## Completed

*(see `.claude/changes/` dated logs for full history predating this file)*

## Deferred

*(none)*
