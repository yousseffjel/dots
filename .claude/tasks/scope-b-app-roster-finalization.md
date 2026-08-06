# Scope B — app / tool / package roster finalization

Epic decomposition per `.claude/rules/foundations/task-planning.md` §
"Any -> Epic". Source request: user spec dated 2026-08-06 (roster
directives given in-chat; the decisions they settled are recorded under
"Locked decisions" below so no sub-task has to re-derive them).

"Layers" here means subsystem areas, as in Scope A: `config/<app>/`
(deployed config), `config/theme/templates/` (theming), `suckless/<tool>`
(C + patches), `packages/` (dnf lists), `scripts/install-*.sh` +
`symlinks.sh` (integration), `docs/` + `KEYBINDINGS.md` (markdown).

---

## Locked decisions (do not re-litigate)

1. **Terminal: alacritty primary, st retained as fallback.** Alacritty
   becomes dwm's `termcmd`, thunar's terminal, and the click-action
   terminal. st stays vendored, patched, built and xresources-themed as
   the no-GPU fallback. Both get themed.
2. **Screenshot: maim + slop**, wrapped in a dmenu-driven
   `config/dwm/bin/dwm-screenshot`, matching the `dwm-powermenu` pattern.
   flameshot was rejected *because* it is Qt.
3. **GTK only — no Qt theming.** Verified against the final roster:
   firefox, thunar, lxappearance, pavucontrol, file-roller, dunst, feh
   are GTK; alacritty is OpenGL with its own config; fastfetch is CLI;
   dwm/st/dmenu/slock are Xlib + xresources. Nothing pulls Qt once
   flameshot is out. Revisit only if a Qt app enters the roster.
4. **Prompt: starship, confirmed.** `conf.d/99-prompt.zsh` is the live
   path and the binary is installed. HyDE's p10k fallback is dead code
   (gated on `HYDE_ZSH_PROMPT=1`, which nothing sets). No `starship.toml`
   ships today, so the prompt runs on stock defaults — sub-task 1 fixes
   that.
5. **cava is dropped** — the template themed a program the installer
   never installed.
6. **kitty is dropped** — packaged but never configured, superseded by
   alacritty.
7. **sxhkd is kept.** dwm retains its base keybinds in `config.def.h`;
   everything else moves to sxhkd.
8. **RAR via `unar` (Fedora official), not `unrar` (RPM Fusion
   nonfree).** Auto-enabling a nonfree third-party repo is a trust
   decision reserved to the user per CLAUDE.md rule 4; `unar` extracts
   RAR from the official repos. Type B assumption — reversible by
   swapping the package and adding the repo note.
9. **Target is a desktop PC, not a laptop, and it is tuned for
   performance.** Consequences that bind every sub-task: no battery
   block, no `power-profiles-daemon`, no lid-close handling, no
   laptop-only power daemons. Lock-on-suspend still applies (desktops
   suspend), so `xss-lock` remains the choice in sub-task 6. Prefer the
   GPU-accelerated path where one exists (alacritty is already that
   choice) and keep recurring background work off the CPU — see
   sub-task 7's interval discipline.
13. **The user's own 405-line `starship.toml` is adopted into the repo**,
   replacing the 103-line ASCII placeholder sub-task 1 shipped. Discovered
   post-merge: `~/.config/starship/` was a real directory holding a
   hand-tuned config, and `symlinks.sh` would have displaced it (backed up,
   not destroyed, per rule 7 — but still a downgrade). The repo should
   reproduce what the user actually runs.
14. **Both `CaskaydiaCove` and `JetBrainsMono` Nerd Fonts get packaged.**
   `fc-list` shows 135 Nerd Font matches on the user's machine and the
   adopted starship config depends on those glyphs (`󰣇`, ``, per-language
   icons), as does `60-aliases.zsh`'s pre-existing `eza --icons`. Without a
   packaged Nerd Font a fresh Fedora install renders tofu. Caskaydia drives
   the prompt/terminal, JetBrains Mono stays for UI surfaces.
11. **zoxide replaces `cd` outright** (`zoxide init zsh --cmd cd`). `cdi`
   becomes the interactive picker. Must degrade safely: `80-tools.zsh`
   already guards on `(( $+commands[zoxide] ))`, so a missing binary
   leaves builtin `cd` intact — that guard is now load-bearing, not
   cosmetic.
12. **Brightness is `xrandr --brightness` (software gamma), not
   `ddcutil`.** A desktop GPU exposes no `/sys/class/backlight`, so
   `brightnessctl` cannot work. `ddcutil` was rejected on cost: each
   DDC/CI call is ~100-300 ms and it needs `i2c-dev` plus a udev rule.
   The trade-off accepted is that this dims the *output signal* only —
   the backlight stays at full power. The block label must not imply
   hardware brightness.

---

## Sub-task 1 — zsh: purge HyDE, retarget at dwm/X11

- Scope: `config/zsh/**`, `config/.zshrc`.
- Delete: `conf.d/00-hyde.zsh`, `conf.d/hyde/` (env.zsh, prompt.zsh,
  terminal.zsh — 338 lines), `completions/hydectl.zsh`, `plugin.zsh`,
  `prompt.zsh`, `user.zsh`, and `config/.zshrc` (byte-identical duplicate
  of `config/zsh/.zshrc`, outside the symlinked dir).
- **`00-hyde.zsh` is currently active** — `.zshrc` sources `conf.d/*.zsh`
  lexically, so it loads first on every interactive shell and exports
  `HYPRLAND_CONFIG` on an X11 box. Read all 248 lines of
  `conf.d/hyde/terminal.zsh` first and reimplement anything worth keeping
  in our own `conf.d/` file before deleting, so nothing regresses
  silently.
- Add: `config/starship/starship.toml` (first one — prompt is on stock
  defaults today) and zoxide as a full `cd` replacement in `80-tools.zsh`
  (locked decision 11).
- The starship `.dcol` template is **sub-task 9's**, not this one's —
  starship.toml has no include mechanism, so theming it means rendering
  the whole file to `${cacheDir}` and pointing `$STARSHIP_CONFIG` at it.
  That is a separable design problem; ship the static config first.
- Check `10-env.zsh` for the XDG exports `hyde/env.zsh` was duplicating,
  and confirm `55-osc133.zsh` does not overlap `terminal.zsh`.
- Exit: `zsh -n` clean on every touched file; a login shell in a
  sandboxed `$HOME` (all four XDG vars + `DISPLAY=`, per the
  installer-test-sandbox memory) reaches a prompt with no errors and no
  `hyde` references anywhere under `config/`.
- Est. sessions: 1.

## Sub-task 2 — packages/*.lst: the final roster (+ starship adoption)

- Scope: `packages/core.lst`, `packages/extra.lst`,
  `config/starship/starship.toml`.
- Add: `alacritty`, `starship`, `zoxide`, `fastfetch`, `firefox`, `maim`,
  `slop`, `xss-lock`, `unar`, `thunar-volman`, `ffmpegthumbnailer`,
  `catfish`, `bluez`, `blueman`, plus the two Nerd Fonts from locked
  decision 14.
- **Not** added: `ddcutil` / `i2c-dev` (locked decision 10 — brightness
  is xrandr gamma), `power-profiles-daemon` (locked decision 9 — desktop).
- **Adopt the user's `~/.config/starship/starship.toml`** (locked decision
  13) over the placeholder. Two edits on adoption, neither cosmetic:
  the `󰣇` Arch logo in `format` is wrong for a Fedora target, and the
  `right_format` block lists ~60 language modules — starship runs detection
  for each on every prompt, which is the one part of the config in tension
  with the "max performance" constraint. Measure the prompt's render time
  before and after any trim rather than assuming; surface the numbers and
  let the user decide how far to cut.
- Note for sub-task 9: the adopted config hardcodes hex colours in ~10
  places (`#8be9fd`, `#769ff0`, `#394260`, `#a0a9cb`, `#9198a1`). Theming it
  means the `.dcol` template rewrites those literals — there is no
  `[palettes]` table to swap, unlike the placeholder it replaces.
- Remove: `kitty`.
- Keep: `sxhkd` (now genuinely used — sub-task 4).
- **Every added name must be verified against
  packages.fedoraproject.org** — there is no `dnf` on the dev host (it is
  Arch), so live `dnf` checks are unavailable. Record the verification
  method in the change log per CLAUDE.md rule 8.
- Blocks nothing structurally, but doing it early means later sub-tasks
  only touch configs.
- Est. sessions: 1.

## Sub-task 3 — alacritty as the main terminal

- Scope: `config/alacritty/`, `config/theme/templates/always/alacritty.dcol`,
  `suckless/dwm/config.def.h` (`termcmd`), `scripts/symlinks.sh`,
  `config/dwm/bin/*` (any terminal invocation), `KEYBINDINGS.md`.
- **Theming trap — the dunst/picom problem, avoided differently.** The
  engine must not write into the repo, and `config/alacritty/` is
  symlinked. So the template renders to
  `${cacheDir}/alacritty-colors.toml` and `alacritty.toml` carries a
  static `import` of that path. That keeps `config/alacritty/` fully
  symlinkable (unlike dunst/picom, which are copied because the engine
  rewrites the whole file). Alacritty's `live_config_reload` picks the
  change up with no reload command, so `reload.sh` needs no new step.
- st stays exactly as-is (locked decision 1).
- Est. sessions: 1.

## Sub-task 4 — sxhkd keybind split

- Scope: `config/sxhkd/sxhkdrc`, `suckless/dwm/config.def.h` (removing
  any binding that moves out), autostart wiring, `KEYBINDINGS.md`,
  `scripts/symlinks.sh`.
- dwm keeps window-management bindings (tags, layouts, focus, spawn
  term/dmenu); sxhkd takes media keys, brightness, volume, screenshot,
  lock, wallpaper/theme, and app launchers.
- **Every volume / mic / brightness binding must fire
  `pkill -RTMIN+<sig> dwmblocks` after changing the value.** Sub-task 7
  runs those three blocks at interval 0 (signal-driven, never polled) —
  without the signal they will never update. Signals: brightness 6,
  mic 7, vol 8.
- ⚠️ `install-suckless.sh` treats `autostart.sh` as user-owned once it
  exists (CLAUDE.md rule 6) — the sxhkd daemon launch must go into the
  template *and* ship a documented note for existing installs.
- Depends on: sub-task 2 (`sxhkd` retained). Coordinate with sub-tasks
  5 and 6, which both add bindings.
- Est. sessions: 1.

## Sub-task 5 — screenshot (maim + slop)

- Scope: `config/dwm/bin/dwm-screenshot`, `config/sxhkd/sxhkdrc`,
  `KEYBINDINGS.md`.
- dmenu mode menu — full / active window / region, each to clipboard /
  file / both — following `dwm-powermenu`'s structure. dmenu is already
  themed by the engine, so the menu is themed with no template work.
- Depends on: sub-task 2 (packages), sub-task 4 (binding location).
- Est. sessions: 1.

## Sub-task 6 — lock / idle

- Scope: autostart wiring, `config/dwm/bin/dwm-powermenu` (Lock entry),
  `config/sxhkd/sxhkdrc`, `KEYBINDINGS.md`, `docs/`.
- `xss-lock` over `xautolock`: it bridges X's screensaver timer *and*
  systemd-logind, so it also locks **on suspend** — which xautolock
  structurally cannot. Lid-close is irrelevant here (locked decision 9,
  desktop), but suspend is not. `xset s 300` sets the idle timer,
  `xset dpms` handles screen blank. slock is already vendored and
  xresources-themed — no new locker work.
- Same `autostart.sh` user-owned caveat as sub-task 4.
- Depends on: sub-task 2, sub-task 4.
- Est. sessions: 1.

## Sub-task 7 — status bar blocks

- Scope: `suckless/dwmblocks/blocks.def.h`,
  `suckless/dwmblocks/scripts/*`, `KEYBINDINGS.md` (click actions).
- **Layout A, confirmed.** The single right-aligned status region, left
  of the systray. No new patch — `extrabar` is not vendored. dwm's
  tags+layout keep the left and the window title keeps the middle.
- **Final block order** (left -> right within the region), with the
  interval/signal discipline the "max performance" constraint demands:

  | # | Block | Interval | Sig | Source | Notes |
  |---|-------|---------:|----:|--------|-------|
  | 1 | updates | 3600 | 1 | cache file | see the `dnf` note below |
  | 2 | disk | 300 | 2 | `df` | click -> thunar on `/` |
  | 3 | temp | 5 | 3 | `/sys/class/hwmon` | |
  | 4 | cpu | 2 | 4 | `/proc/stat` | **script exists** (sig 1 -> 4) |
  | 5 | ram | 10 | 5 | `/proc/meminfo` | **script exists** (sig 2 -> 5) |
  | 6 | brightness | **0** | 6 | `xrandr --verbose` | software gamma; per-output |
  | 7 | mic | **0** | 7 | `pamixer --default-source` | click -> mute |
  | 8 | vol | **0** | 8 | `pamixer` | click -> mute, scroll -> +/-5%, right -> pavucontrol |
  | 9 | bluetooth | 30 | 9 | `bluetoothctl` | click -> blueman-manager |
  | 10 | clock + date | 60 | 10 | `date` | **script exists** (sig 3 -> 10) |
  | — | systray | — | — | — | native, always furthest right |

- **Interval 0 means signal-driven only** — brightness, mic and vol never
  poll. They refresh solely when sub-task 4's sxhkd bindings fire
  `pkill -RTMIN+<sig> dwmblocks` after changing the value. That is the
  performance-correct design and it couples this sub-task to sub-task 4:
  every audio/brightness binding there must send its signal.
- **The three existing scripts are renumbered** (cpu 1->4, ram 2->5,
  clock 3->10). `blocks.def.h` and any `pkill -RTMIN+n` reference must
  move together or clicks route to the wrong block.
- **`dnf check-update` must never run inside the block.** It hits the
  network and can take seconds. The block reads a cache file refreshed
  out-of-band (systemd user timer, hourly) or uses `dnf -C check-update`
  cache-only at most. A polling block that shells out to the network is
  exactly what the performance constraint forbids.
- Dropped from the candidate list: battery (desktop), now-playing,
  keyboard layout, weather, uptime/load, network. Add later if wanted —
  each is one script plus one `blocks.def.h` row.
- Blocks need no template work: they source
  `$XDG_CACHE_HOME/dots/theme/statusbar-colors.sh`, which `statusbar.dcol`
  already generates.
- New packages: `bluez` + `blueman` (bluetooth block only). Brightness
  needs nothing — `xrandr` is already in `extra.lst`.
- Depends on: sub-task 2 (bluez/blueman), sub-task 4 (signal senders).
- Est. sessions: 1-2 — seven new scripts.

## Sub-task 8 — thunar finalization

- Scope: `config/thunar/` (thunarrc, uca.xml), `config/xfce4/helpers.rc`,
  xdg-mime defaults, `scripts/install-restore.sh`, `scripts/symlinks.sh`.
- Archive handling via `thunar-archive-plugin` + `file-roller` (both
  already packaged) + `unar` for RAR; `thunar-volman` + `gvfs` for
  auto-mount; `tumbler` + `ffmpegthumbnailer` for video/PDF thumbnails;
  `catfish` for Dolphin-style search.
- `TerminalEmulator=alacritty` in `helpers.rc`; custom actions for "Open
  Terminal Here" and "Set as Wallpaper" (-> `dwm-wallpaper`).
- xdg-mime defaults so firefox / alacritty / feh own their types.
- GTK theming is already covered by the existing `gtk.dcol` — no new
  template.
- Depends on: sub-task 2 (packages), sub-task 3 (alacritty must exist
  before it is named as the terminal).
- Est. sessions: 1.

## Sub-task 9 — fastfetch, starship theming, cava removal, docs

- Scope: `config/fastfetch/`, `config/theme/templates/always/fastfetch.dcol`,
  `config/theme/templates/always/starship.dcol`,
  delete `config/theme/templates/always/cava.dcol`,
  `config/theme/templates/always/README.md`, `docs/THEMING.md`,
  `KEYBINDINGS.md`, `ROADMAP.md`, `CLAUDE.md` (roster + project map).
- **starship theming needs the `$STARSHIP_CONFIG` trick.** starship.toml
  has no include/import directive, so a palette cannot be spliced in.
  The template renders the *whole* config to
  `${cacheDir}/starship.toml`, and `99-prompt.zsh` points
  `$STARSHIP_CONFIG` at it when present, falling back to the symlinked
  repo copy otherwise. Same principle as alacritty (sub-task 3): the
  engine writes only to the cache, never into the repo.
- **Folds the queued "document the vim + cava templates in THEMING.md"
  item** — it becomes vim + fastfetch, since cava is being removed.
- Reconciles `CLAUDE.md`'s "Still genuinely pending" list, which this
  Epic invalidates (screenshot and lock/idle both land here).
- Depends on: everything above (it documents the final state).
- Est. sessions: 1.

## Sub-task 10 — picom performance tuning

- Scope: `config/theme/templates/always/picom.dcol`,
  `config/picom/picom.conf`, `docs/THEMING.md`.
- Added at the user's request under the "max performance" constraint
  (locked decision 9).
- **The template writes the whole file — both copies must change
  together.** `picom.dcol`'s header targets
  `${confDir}/picom/picom.conf` and regenerates it in full on every
  wallpaper change. So `config/picom/picom.conf` (the installer-copied
  pre-theme state) and `picom.dcol` (the post-theme state) must carry
  identical performance settings, or the first wallpaper change silently
  reverts the tuning. This is the single highest-risk thing in the
  sub-task.
- Baseline is already sane: `backend = "glx"`, `vsync = true`,
  `use-damage = true`, no blur, no rounded corners.
- Candidates to evaluate, not assume: `unredir-if-possible` (lets
  fullscreen games bypass the compositor entirely — the biggest single
  win, but it can cause a flicker on window transitions),
  `xrender-sync-fence` (NVIDIA tearing/corruption workaround; a
  measurable cost on non-NVIDIA, so gate it on the driver),
  shadow/fade cost review, and per-window `unredir` rules.
- Each change must be justified as a real cost, not cargo-culted from a
  "picom performance config" gist. Where a setting trades correctness for
  speed, record the trade-off in the change log.
- Depends on: nothing. Independent of every other sub-task.
- Est. sessions: 1.

---

## Sequencing

1 and 2 are independent and unblock everything else. 3 before 8. 4
before 5 and 6. 7 and 10 are independent. 9 last — it documents the
final state.

```
1 (zsh) ─┐
2 (pkgs) ┼─> 3 (alacritty) ──> 8 (thunar) ──┐
         ├─> 4 (sxhkd) ─┬─> 5 (screenshot) ─┼─> 9 (docs)
         │              └─> 6 (lock/idle) ──┤
         └─> 7 (statusbar) ─────────────────┤
10 (picom) ───────────────────────────────── ┘
```

## Out of scope

Ported from HyDE's roster and deliberately rejected: waybar, dolphin,
Kvantum/qt5ct/qt6ct, hyprlock/hypridle/hyprsunset, rofi, wlogout,
uwsm, xdg-desktop-portal-hyprland, MangoHud + gaming stack, spotify +
spicetify, VS Code flag files, lsd, duf, fish. All are Wayland-specific,
KDE-specific, superseded by an existing choice here (dmenu over rofi,
eza/bat over lsd/duf), or outside a dotfiles repo's remit.
