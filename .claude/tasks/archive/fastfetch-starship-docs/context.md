# Context — fastfetch-starship-docs

## Background

Epic sub-task 9 of `.claude/tasks/scope-b-app-roster-finalization.md`, the
last of eleven and last by design — it documents the final state. Sub-tasks
1–8, 10 and 11 are all merged.

## Prior Decisions

- **Locked decision 5** — cava is dropped; the template themed a program the
  installer never installs. `cava` appears in no `packages/*.lst`.
- **Locked decision 13** — `config/starship/starship.toml` is the user's own
  adopted config, trimmed 405 → 151 lines in sub-task 2 with byte-identical
  prompt output. Any refactor here must clear the same bar.
- **Locked decision 15** — the font family is `Cascadia Code NF`. The
  starship glyphs and any fastfetch icons depend on a Nerd Font being present.
- **Locked decision 9** — desktop, tuned for performance.
- Sub-task 2's note: the adopted starship config hardcodes hex in ~10 places
  and has no `[palettes]` table, so theming means rewriting literals.

## User decisions this session (2026-08-07, four questions, all recommended
option taken)

1. **starship → palette splice.** Refactor the 5 themed hex literals to
   palette colour names; the `.dcol` renders only the `[palettes.dots]` block;
   a post-command concatenates repo config + palette into the cache;
   `$STARSHIP_CONFIG` points at the cache copy.
2. **fastfetch → template-only.** No `config/fastfetch/` in the repo at all.
3. **fastfetch content** → Fedora logo + desktop-focused module set (os,
   kernel, uptime, packages, shell, wm, terminal, cpu, gpu, memory, disk,
   colour bar).
4. **No shell greeting** — fastfetch stays a command you type.

## References

- `config/theme/templates/always/README.md` — the three target styles; this
  task adds a fourth (template-only, no static base).
- `scripts/install-restore-theme.sh` — `theme_claim_gtk_css()` is the exact
  precedent for claiming a template-written file in the manifest with no
  static copy under `config/`.
- `config/theme/templates/always/cava.dcol` — the splice-below-a-marker
  post-command pattern starship will reuse. Deleted by step 4.
- `tests/picom-lockstep.sh` — sandboxed single-template engine run.
- `.claude/changes/2026-08-06-theming-app-templates.md` — why vim and cava
  render to `${cacheDir}` rather than to their real targets.

## Notes — verified this session, not assumed

- **starship 1.26.0**: `palette = 'x'` + `[palettes.x]` resolves to truecolor
  (`#ff0000` → `38;2;255;0;0`). A `palette` naming a **missing** table drops
  the colour and writes `[WARN] - (starship::config): Could not find color
  palette: dots` to stderr **twice on the first prompt of each shell
  session** — deduplicated thereafter via `$STARSHIP_CACHE/session_<key>.log`.
  Measured with a controlled `STARSHIP_SESSION_KEY`: 2/0/0 lines across three
  renders in one session, 2 again for each new key. So it is once per new
  terminal, not once per render — the repo copy must still always carry a
  default `[palettes.dots]`. No include/import directive exists (confirmed via
  Context7 + the starship.rs config docs).
- **`[git_status] style = "bg:#394260"` is dead** — the inner `(fg:…)` span
  covers the whole segment, so the outer `($style)` has no cells to paint.
  Swapping it for bright red gives byte-identical output. Kept and themed
  rather than deleted (no behaviour change either way).
- **fastfetch 2.66.0**: `--config a --config b` → `Error: only one config
  file can be loaded`. No include key in the JSONC schema. Supports 24-bit
  colour as `#RRGGBB` / `{##RRGGBB}` (hex form since v2.42.0).
- **fastfetch costs 4–5 ms** for a compact module set on this host, so the
  performance constraint did not decide question 4.
- Only **5 hex literals** in `starship.toml` need theming: `#8be9fd`
  (directory), `#9198a1` (git_branch), `#769ff0` (git_status fg), `#394260`
  (git_status bg), `#a0a9cb` (time). The language modules use `bold
  bright-cyan`-style ANSI names, which already follow the terminal palette
  the engine themes through xresources/alacritty — they need no work.
- `config/gtk-3.0/` does **not** exist in the repo; `gtk.css` is written only
  by `gtk.dcol` and claimed by the installer. That is the fastfetch precedent.
- **fastfetch exit status is not a sufficient config check.** Malformed JSON
  (rc 221) and an unsubstituted `<wallbash_*>` in a colour (rc 223, "invalid
  RGB color code found") are both caught — but an **unknown module type is
  silently ignored with rc 0**, and the module just vanishes from the output.
  Verified: renaming `kernel` to `kernelz` drops the kernel line and still
  exits 0. So the test must assert on the rendered module names.
- **zsh's `-nt` is not bash's.** `[[ a -nt b ]]` with `b` missing is **false**
  in zsh and **true** in bash. 99-prompt.zsh spells the missing-file case out
  rather than relying on either.
- The engine skips a template whose target's **parent directory** is missing
  (`apply-templates.sh:163-166`), treating that as "app not installed" — so
  `~/.config/fastfetch/` must be created by the installer or fastfetch is
  silently never themed.
