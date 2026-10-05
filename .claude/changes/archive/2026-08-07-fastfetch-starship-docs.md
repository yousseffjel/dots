# fastfetch-starship-docs

Date: 2026-08-07
Files: 12 | Lines: +829/-85 (source only; +1070/-88 incl. task folder + state)

Epic sub-task 9 of `.claude/tasks/scope-b-app-roster-finalization.md` — the
last of eleven, and last by design because it documents the final state.
**This closes the Epic.**

## What changed

- **starship is themed by splicing, not regeneration.** `config/starship/
  starship.toml` keeps its structure and its symlink; its five painted hex
  literals became palette names (`c_dir`, `c_git_branch`, `c_git_status`,
  `c_git_status_bg`, `c_time`) resolved from a `[palettes.dots]` table below a
  new `# ### dots-theme palette ###` marker.
- **`config/theme/templates/always/starship.dcol` (new)** renders *only* that
  table. Its post-command writes a themed copy to `${cacheDir}/starship.toml`
  — everything above the marker in the repo config, plus the fresh table —
  via a `.new` file and `mv` so a prompt rendering mid-apply never reads a
  half-written config.
- **`config/zsh/conf.d/99-prompt.zsh`** picks between the two: the themed copy
  while it is newer than the repo config, the repo config otherwise, and an
  inherited `$STARSHIP_CONFIG` always wins.
- **`config/theme/templates/always/fastfetch.dcol` (new)** writes the whole
  `~/.config/fastfetch/config.jsonc` — Fedora logo, a desktop-focused module
  set (os, kernel, uptime, packages, shell, wm, terminal, cpu, gpu, memory,
  disk) and the colour bar. **No `config/fastfetch/` exists in the repo**;
  the template is the only authored copy, exactly as `gtk.css` already works.
- **`scripts/install-restore-theme.sh`** gained `theme_claim_fastfetch()`,
  which creates `~/.config/fastfetch` and claims the path in the install
  manifest. It runs before `theme_backup_preexisting`, so a pre-existing
  config is preserved before the template can overwrite it.
- **`config/theme/templates/always/cava.dcol` deleted** (locked decision 5 —
  it themed a program the installer never installs).
- **Docs:** the templates `README.md` gained an "engine-owned targets with no
  static base config" section; `docs/THEMING.md` gained an "App templates"
  section covering alacritty/starship/fastfetch/vim plus three new
  troubleshooting entries; `CLAUDE.md` and `ROADMAP.md` were reconciled
  (below). `KEYBINDINGS.md` needed no change — this sub-task adds no bindings.
- **`tests/starship-template.sh` and `tests/fastfetch-template.sh` (new)** —
  16 assertions, picked up automatically by CI's `tests/*.sh` glob.

## Why

The scope file assigned this sub-task the two remaining themable apps plus
every doc claim the Epic had invalidated. Both apps needed a decision first,
because **neither starship nor fastfetch has an include directive** — verified,
not assumed: Context7 plus the starship.rs config docs for one, and
`fastfetch --config a --config b` returning `Error: only one config file can
be loaded` for the other. So a palette cannot simply be imported.

The user chose the recommended option on all four questions. For starship,
splicing keeps the 151-line prompt structure in one place and duplicates only
the ~8-line palette table — as against a full-file render, which would have
recreated the `picom.conf`/`picom.dcol` lockstep hazard the scope file called
sub-task 10's highest risk. For fastfetch, template-only ownership removes
that hazard entirely at the cost of two installer obligations.

## Assumptions

- **(Type B) `[git_status] style = "bg:#394260"` was themed rather than
  deleted.** It currently paints nothing — the inner `(fg:…)` span covers the
  whole segment, so the outer `($style)` has no cells left; swapping it for
  bright red gives byte-identical output. Kept because deleting a line from
  the user's adopted config is a bigger change than mapping it, and the value
  is then already right if the format ever grows a gap.
- **(Type C) Palette mappings follow existing template conventions** rather
  than matching the original hex: `1xa5` is `statusbar.dcol`'s MUTED, `1xa7`
  its ACCENT1, and `1xa8`/`3xa8`/`1xa2` are `alacritty.dcol`'s bright blue,
  bright cyan and selection background. The prompt reads as one theme with the
  bar and the terminal instead of approximating its old Dracula-ish colours.
- **(Type C) The language modules were left on ANSI names** (`bold
  bright-cyan` and friends). Those resolve against the terminal's 16-colour
  palette, which `xresources.dcol` and `alacritty.dcol` already theme —
  converting them would theme them twice.

## Trade-offs

**Three of my own claims were wrong and were corrected by testing, not by
review.** Each had been written into shipped config comments first:

1. *"starship warns on every prompt render."* It warns **twice on the first
   prompt of each shell session**, then dedupes through
   `$STARSHIP_CACHE/session_<key>.log`. Measured with a controlled
   `STARSHIP_SESSION_KEY`: 2/0/0 across three renders in one session, 2 again
   for each new key. The conclusion held — a default table is still required,
   because once per new terminal is worse to look at, not better — but the
   stated reason was false.
2. *"`-nt` is true when the right-hand file is missing."* That is **bash**.
   **zsh returns false**, and `99-prompt.zsh` is zsh. Relying on the bash
   reading would have silently dropped the themed config on a box where
   `symlinks.sh` never ran — precisely the box that needs it. The condition
   now spells the missing-file case out.
3. The first version of the fastfetch skip assertion checked only that no
   file appeared. That is equally true when the engine *errors* as when it
   *skips*, so it passed with the engine's install-check mutated to
   `if false`. It now asserts on the skip message.

**A second false pass, found by shimming rather than by reading.** The
starship assertion counted warning lines but ignored exit status, so a
`starship` replaced by `exit 127` produced zero warnings and passed. It now
checks both, and the shim is caught.

**The oversized test was split, not excepted.** `tests/theme-templates.sh`
reached 294 lines against the 250-line cap, and was the only shell script in
the repo over it (next largest: 246), so there was no precedent for an
exception. Split into two siblings (202 + 203) that duplicate a short harness
on purpose — the same stance CLAUDE.md rule 2 takes on per-script colour
helpers. Markdown over the cap (`THEMING.md` 333, `ROADMAP.md` 392) was left
alone; `KEYBINDINGS.md` has been at 422 for some time.

**Documentation reconciliation was the bulk of the diff, and two CLAUDE.md
claims were flatly false rather than merely stale:** "No CI, no linter config,
no test suite" (all three have existed since 2026-08-05) and "README.md is
still a 7-byte stub" (54 lines, with a CI badge). Also corrected: the dwm
patch roster still named `scratchpads`, retired in sub-task 11; the project
map predated nine `config/` entries and six `scripts/` entries; and ROADMAP
§3's status column listed screenshot, lock/idle, compositor, notifications,
wallpaper, display manager, session autostart and system tray as `❌ add`.

**Every path and function name written into the docs was checked to resolve
before shipping** — `install-session.sh` and `dwm-brightness` were found
missing from a first draft of the project map that way.

## Follow-ups

- **picom is never launched.** Found while reconciling ROADMAP §3: it is
  packaged, configured, themed and performance-tuned in sub-task 10, but it
  appears in no autostart path — not `autostart.sh`, not `.xinitrc`, not
  sxhkd — and `reload.sh` only signals it *if already running*. So sub-task
  10's tuning has never taken effect on a real session. Fixing it means
  `scripts/install-session.sh`, outside this plan's `## Allowed`, so the
  ROADMAP row was corrected to `⚠️ partial` and the fix left queued.
  **Note `autostart.sh` is user-owned once it exists (CLAUDE.md rule 6)**, so
  existing installs will need the line added by hand.
- **`theme_is_ours()` still carries the `pipefail` SIGPIPE bug** already in
  the MASTER_PLAN queue, and `theme_claim_fastfetch` now calls it. Left alone
  deliberately: it is a distinct queued item owing its own change log, and the
  impact is bounded — a redundant backup and a misleading "left untouched"
  message, only at manifest sizes far beyond the real handful of rows.
- **Nothing ran on real Fedora.** The prompt and fetch output were rendered on
  **Arch**, so the fastfetch `packages`/`wm` lines and the Fedora logo path
  are inferred for the target, not observed. No wallpaper change was performed
  on the live desktop — the engine only ever ran against throwaway trees
  holding a single template.
- **No dwm rebuild is needed** for this sub-task; no C changed.
- With sub-task 9 merged the roster Epic is complete (11/11). The remaining
  MASTER_PLAN queue items are unrelated to it, except the `core.lst`/
  `extra.lst` review, which five sub-tasks have now fed.

## Test coverage

- **All six `tests/*.sh` pass**: `build.sh` (after `rm -f
  suckless/*/config.h`, so the build could not pass on a stale generated
  header), `lint.sh`, `pkglist.sh`, `picom-lockstep.sh`,
  `starship-template.sh` (7 assertions) and `fastfetch-template.sh` (9).
- **8 mutants, all caught** — wrong placeholder, broken sed range, removed
  marker guard, deleted palette table, unknown fastfetch module type, unknown
  placeholder, malformed JSON, and the engine's install-check removed. Two of
  those (the last, and the starship exit-status case) were **not** caught by
  the first version of the tests and drove real fixes.
- **The starship refactor is proved byte-identical**, not asserted: five
  prompt surfaces (plain dir with status 0 and 1, and a git repo with staged,
  modified and untracked files plus a marker file for every kept language),
  left and right prompts, with a cold `STARSHIP_CACHE`. 1010 bytes, identical.
- **The generated configs were fed to the real binaries.** starship renders
  the spliced config with exit 0 and no warnings; fastfetch parses the
  generated JSONC and renders all 11 modules. That last check matters because
  **fastfetch ignores an unknown module type and still exits 0** — renaming
  `kernel` to `kernelz` drops the line silently — so exit status alone would
  not have caught a typo.
- **`theme_claim_fastfetch` was exercised in a sandboxed `$HOME`** with all
  four XDG vars overridden: dry-run mutates nothing, the real run creates the
  directory and writes exactly one manifest row, and a second run adds none.
  The user's real manifest was checked before and after — 3 rows both times,
  no `/tmp` paths.
- **`99-prompt.zsh` verified through a real interactive startup** (`script`
  PTY, `ZDOTDIR` pointed at this worktree, not the symlinked main one) across
  six states: neither file, repo only, themed newer, repo edited after,
  themed only, and an inherited `$STARSHIP_CONFIG`. No startup errors.
- **`dunst` held PID 1704 throughout.** Every engine run used a throwaway
  `DOTS_DIR` holding one template plus fake `pkill`/`xrdb`/`setsid` on `PATH`
  and `env -u DISPLAY`.
