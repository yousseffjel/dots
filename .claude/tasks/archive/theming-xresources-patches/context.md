# Context — theming-xresources-patches

## Background
Sub-task 1 of the theming-engine Epic (`.claude/tasks/scope-a-theming-engine.md`).
User wants a HyDE-wallbash-inspired dark-mode-only theming engine for the
Fedora+dwm+X11+suckless stack. This sub-task is the prerequisite: every
tool must be able to read live colors from the X resource database before
any template engine or reload script has something to target.

## Prior Decisions
- This repo has no `config.h` for dwm/st/dmenu/slock — only `config.def.h`.
  All prior patches (status2d, systray, statuscmd, pertag, etc.) are baked
  directly into the vendored `.c`/`config.def.h` sources; `patches/*.diff`
  files are a documentation record, not auto-applied at build time (checked
  `scripts/install-suckless.sh` — it does not reference `patches/` at all).
- Suckless patches convention (CLAUDE.md rule 5): vendor as `.diff` under
  `patches/`, named `<patch>-<version-or-date>-<hash>.diff`.

## References
- Upstream patches fetched via curl (raw bytes, not WebFetch's paraphrased
  summary, to avoid transcription drift in whitespace-sensitive diffs):
  - dwm: dwm.suckless.org/patches/xresources/dwm-xresources-20260524-44dbc68.diff
  - st: st.suckless.org/patches/xresources-with-reload-signal/st-xresources-signal-reloading-20220407-ef05519.diff
  - dmenu: tools.suckless.org/dmenu/patches/xresources/dmenu-xresources-20260510-7175c48.diff
  - slock: tools.suckless.org/slock/patches/xresources/slock-xresources-20191126-53e56c7.diff
- Per-tool `patches/PATCHES.md` has full merge-decision detail.

## Notes
- All 4 builds verified clean (`make clean && make`), zero new warnings
  beyond pre-existing ones already in vanilla st.c.
- Resource naming follows the user's spec exactly for dwm/st/dmenu
  (normbgcolor/selbgcolor style, not upstream's mixed foreground/Sel style).
  slock has no explicit spec naming, so it follows the same descriptive
  convention rather than upstream's numbered color0/color1/color3 scheme.
