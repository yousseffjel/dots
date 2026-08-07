# Plan — alacritty-main-terminal

## Goal
Make alacritty the primary terminal: a static `config/alacritty/`, themed via
`${cacheDir}` so the engine never writes into the repo, dwm's `termcmd` pointed
at it, fonts retargeted at `Cascadia Code NF`. st stays the no-GPU fallback.

## Scope
- `config/alacritty/**`, `config/theme/templates/always/**`
- `suckless/*/config.def.h`, `scripts/symlinks.sh`, `KEYBINDINGS.md`

## Allowed
- config/alacritty/*
- config/theme/templates/always/*
- suckless/*/config.def.h
- scripts/symlinks.sh
- KEYBINDINGS.md

## Forbidden
- suckless/dwm/dwm.c
- suckless/*/patches/*
- scripts/theme/*
- packages/*

## Steps
1. `config/alacritty/alacritty.toml` — base config + import of cache palette.
2. `always/alacritty.dcol` — render palette to `${cacheDir}`.
3. dwm — `termcmd` -> alacritty; `fonts[]`/`dmenufont` -> Cascadia Code NF.
4. dmenu + st — same font, kept in step.
5. `symlinks.sh` — link `config/alacritty`.
6. Docs — `KEYBINDINGS.md` terminal row + rebuild caveat; templates `README.md`.
7. Verify — toml parse, render against `themes/dark/`, `make` all three.

## Out of scope
- Scratchpads (Epic sub-task 11), sxhkd (4), thunar terminal (8), picom (10).

## Risks
- Wrong family string renders tofu — pinned to verified `Cascadia Code NF`.
- `config.h` generated once then left alone — stale builds miss this; document.
