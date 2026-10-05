# dmenu-only-drop-rofi

## Session Date
2026-08-05

## Context
User asked (in-chat): "can we drop rofi and focus to keep use just dmenu and
make it can run all what i need", then confirmed with "make dmenu the main
and only one and start made scripts are needed (make folder for scripts)".
rofi was never actually installed or scripted in this repo — it only
appeared in `ROADMAP.md` as an aspirational recommendation copied from
comparing this repo against HyDE-Project/HyDE. dmenu is already vendored at
`suckless/dmenu/` with 7 patches (see
`.claude/changes/2026-08-04-dmenu-patched-build.md`).

A follow-up user message added three more constraints: use `Super+Shift+x`
for the powermenu keybind specifically, work directly on `main` with no
git-worktree slot, add a clipboard-manager script as well, and check
Context7 MCP for documentation on each tool used.

## What Was Requested
1. Drop rofi from the roadmap/plan; make dmenu the sole launcher/menu tool.
2. Create a folder for the runtime scripts this requires.
3. Powermenu keybind: `Super+Shift+x`.
4. Skip the usual `/plan` git-worktree-per-task slot model for this task —
   work on the same branch (`main`) directly.
5. Add clipboard-manager support as well (originally scoped out as a new,
   unapproved external dependency; the user approved it in response to that
   flag).
6. Use Context7 MCP to verify documentation for each tool/library touched.

## What Was Implemented or Decided
- New `config/dwm/bin/dwm-powermenu` script: a dmenu menu offering
  lock / logout / suspend / reboot / shutdown. Lock uses the already-vendored
  `slock`; logout sends `SIGTERM` to `dwm` (dwm's own signal handler then
  exits cleanly, which ends the X session since `.xinitrc` does `exec dwm`);
  suspend/reboot/shutdown use `systemctl`. Reboot and shutdown require a
  second yes/no dmenu confirmation before executing.
- New `config/dwm/bin/dwm-clipmenu` script: a dmenu frontend over CopyQ's
  clipboard history (`copyq eval 'count()'`, a single batched
  `copyq separator $'\x1e' read <indices>` call, `copyq select <idx>`).
  CopyQ was chosen because it's already an installed package in both
  `install-arch.sh` and `install-fedora.sh` ("desktop utilities, clipboard &
  file management" line) — no new external dependency was actually
  introduced despite this being a scope addition.
- `suckless/dwm/config.def.h`: added `powermenucmd`/`clipmenucmd` spawn
  argv arrays and two new keybinds — `Mod4Mask|ShiftMask, XK_x` →
  `dwm-powermenu`, `Mod4Mask|ShiftMask, XK_c` → `dwm-clipmenu`. `MODKEY` in
  this config is `Mod1Mask` (Alt); the user explicitly asked for Super
  (`Mod4Mask`) on these two specifically, which was previously entirely
  unused in this keymap, so there's no collision with any existing bind.
  App launching itself needed no new script — it was already solved by
  dwm's existing `dmenucmd` (`Mod+p` → `dmenu_run`,
  `suckless/dwm/config.def.h:92`).
- `scripts/symlinks.sh`: added `config/dwm -> ~/.config/dwm` to the `LINKS`
  array, following the same directory-symlink pattern already used for
  `config/tmux` and `config/zsh`.
- `config/zsh/conf.d/20-path.zsh`: added `$HOME/.config/dwm/bin` to the
  `path` array so `dwm-powermenu`/`dwm-clipmenu` resolve via `execvp`'s PATH
  search when dwm's `spawn()` invokes them by name.
- `ROADMAP.md`: struck rofi/clipmenu across every recommendation row that
  applies to *this* repo — the launcher/powermenu/clipboard-manager rows in
  the HyDE-comparison table (§3), the Fedora package list (§4), the pywal
  template list and `themes/<name>/` dir spec (§2.4/§8), the
  `x11/autostart.sh` daemon list (§5), the `scripts/` table and dwm-keybind
  table (§6/§7), and the build-order step 3 (§9) — replacing them with
  dmenu + the two new scripts (or, where dmenu has no equivalent, an
  explanatory note — e.g. dmenu has no `rofi.rasi`-style runtime theme file
  since its colors are compile-time constants in `config.def.h`).
  `ROADMAP.md:29`, which describes HyDE's own repository structure as a
  comparison source, was deliberately left untouched — it's not a
  recommendation for this repo.
- `CLAUDE.md`: project map updated to list `config/dwm/bin/`; the "Config"
  tech-stack line and `symlinks.sh` map comment updated to mention it;
  roadmap-status section updated to note that launcher/powermenu/clipboard
  are now done via dmenu, not rofi.
- Verified `suckless/dwm/config.h` (a gitignored, locally-generated build
  artifact — not part of the committed source) was kept in sync with
  `config.def.h`, and `make -C suckless/dwm` compiles clean with the new
  keybinds, no warnings.
- Ran the `audit-loop` skill against this diff (Medium+ tier by file count,
  7 files touched). Its checklist is written for a React Native/FSD app;
  none of that maps onto a bash/C dotfiles repo, so checks were substituted
  with shell/C-appropriate equivalents (quoting, error propagation,
  subprocess cost, unused vars). Found and fixed two real issues in
  `dwm-clipmenu`: (1) it was spawning one `copyq` subprocess per clipboard
  history item to build the menu — replaced with a single batched
  `copyq separator ... read` call; (2) its dmenu flags were inlined instead
  of using the same `DMENU_OPTS` array pattern as `dwm-powermenu` — unified
  for consistency.
- Spawned the `reviewer` subagent gate. First pass returned `WARN`: it
  caught that `ROADMAP.md:197` still listed rofi in the Fedora package list,
  inconsistent with the rest of the diff. Re-sweeping the file for that
  pattern found three more misses in the same category (the pywal-template
  line, the `themes/<name>/` `rofi.rasi` line, and the autostart.sh
  `clipmenud` mention) plus one in `CLAUDE.md` (a roadmap-status bullet that
  had gone stale the moment the ROADMAP rows it referenced were fixed). All
  four were corrected; the reviewer re-checked and returned `READY`.

## Files Modified
- `config/dwm/bin/dwm-powermenu` (new)
- `config/dwm/bin/dwm-clipmenu` (new)
- `suckless/dwm/config.def.h` (modified)
- `suckless/dwm/config.h` (local build artifact, gitignored — kept in sync, not part of the commit)
- `scripts/symlinks.sh` (modified)
- `config/zsh/conf.d/20-path.zsh` (modified)
- `ROADMAP.md` (modified — untracked file, pre-existing content)
- `CLAUDE.md` (modified — untracked file, pre-existing content)

## Key Technical Decisions
1. **CopyQ over clipmenu/greenclip.** CopyQ is already an installed package
   in both `install-arch.sh` and `install-fedora.sh`, so fronting it with
   dmenu avoids adding a genuinely new external dependency even though
   "add clipboard as well" was itself a scope addition mid-task. If wrong:
   swap `dwm-clipmenu`'s `copyq` calls for `clipmenu`/`greenclip` CLI
   equivalents.
2. **Batched clipboard read, not one-call-per-item.** Caught during the
   audit-loop Size/Performance pass — a history of 100+ entries would
   otherwise fork a `copyq` subprocess per row. Fixed with
   `mapfile -d $'\x1e' -t items < <(copyq separator $'\x1e' read <indices>)`.
   If wrong (e.g. some clipboard content interacts badly with the `\x1e`
   separator): revert to the simpler per-item loop.
3. **Confirmation step on reboot/shutdown only.** Not explicitly requested;
   added because a single mis-highlighted `Return` in a dmenu list is real
   risk for a destructive, irreversible action, whereas lock/logout/suspend
   are all safely reversible. If wrong: delete the `confirm "..." &&` guard
   on those two `case` branches in `dwm-powermenu`.
4. **Super (`Mod4Mask`), not `MODKEY`, for the two new binds.** Explicit
   user instruction ("super + shift + x"), not a default choice — `MODKEY`
   in this config is `Mod1Mask` (Alt).
5. **No worktree/slot for this task.** User explicitly said "do not use
   worktree, work on same code base same branch" mid-task, overriding the
   global `CLAUDE.md`'s usual git-worktree-per-task model. A slot worktree
   (`.claude/worktrees/dmenu-only-drop-rofi/`, branch
   `slot/dmenu-only-drop-rofi`) had already been created via `/plan` before
   this instruction arrived; it was torn down with
   `git worktree remove --force` + `git branch -D` before any work happened
   inside it, so no artifacts from it remain.
6. **copyq is not autostarted.** `dwm-clipmenu` starts CopyQ on-demand
   (`pgrep -x copyq || setsid -f copyq`) rather than editing
   `scripts/install-suckless.sh`'s `autostart.sh` template — kept the
   change scoped to the two new script files and the minimum wiring needed
   to run them, rather than also touching the installer. See Next Steps.

## Assumptions Made
- **Type B** — "add clipboard as well," said immediately after this task had
  explicitly scoped clipboard support out for needing an unapproved new
  dependency (`clarification-first.md` invariant #6), was treated as the
  required approval for that dependency. It turned out moot since CopyQ was
  already installed.
- **Type C** — used Context7 MCP (per explicit user instruction) to verify:
  dmenu's CLI flags (context7's suckless.org index had no matching content,
  so the actual vendored `suckless/dmenu/dmenu.1` man page and `dmenu.c`
  `getopt`-equivalent parsing were used as ground truth instead — arguably
  more authoritative than generic docs for this specific patched build);
  CopyQ's CLI/scripting API (`count()`/`read()`/`select()`, library
  `/hluk/copyq`); and systemd's `loginctl`/`logind` session-management
  semantics (library `/systemd/systemd`) before writing either script.

## Trade-offs
- Chose to keep `dwm-clipmenu` self-contained (starts CopyQ on demand)
  rather than also editing `install-suckless.sh`'s autostart template to
  launch it at session start. Trade-off: clipboard history only starts
  accumulating from whenever CopyQ was first started in a session, not from
  login — but it kept this task's file surface to exactly what "make dmenu
  the only one, add the scripts" asked for, without also touching the
  installer's autostart generation logic.
- Left `ROADMAP.md`'s "Lock screen" row saying slock is "❌ add" even though
  it's already vendored and built — pre-existing staleness unrelated to
  rofi/dmenu, out of scope for this task.

## Open Questions / Blockers
N/A

## Next Steps
- Consider adding a `copyq` startup line to `scripts/install-suckless.sh`'s
  generated `autostart.sh` template (mirroring the existing
  `dwmblocks`-launch pattern) so clipboard history persists continuously
  across reboots rather than only from whenever CopyQ was last started.
- Not tested interactively against a live X/dwm session — no display
  available in this environment. Verification here was static only:
  `bash -n` on both new scripts, `make -C suckless/dwm` compiles clean, and
  a manual check that the two new keybinds don't collide with any entry in
  the existing `keys[]` array. Should be smoke-tested on real hardware
  (`Super+Shift+x`, `Super+Shift+c`) before relying on it.
- `KEYBINDINGS.md` still doesn't exist (pre-existing gap, noted in
  `CLAUDE.md`'s roadmap-status) — once it does, add these two new binds to
  it.
