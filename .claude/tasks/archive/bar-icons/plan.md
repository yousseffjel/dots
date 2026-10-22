# Plan — bar-icons

## Goal
Replace the dwmblocks text labels (UPD, DISK, TEMP, CPU, MEM, GAMMA/BL, MIC,
VOL, NET, BT, BAT) with Nerd Font glyphs from the vendored Cascadia Code NF,
state-aware where the block already knows the state, with compact values
(user decision 2026-10-22: "Icon + compact value", state-aware icons; the
clock is left exactly as it is).

## Scope
- suckless/dwmblocks/scripts/dwm-*
- tests/blocks-*.sh, tests/dwm-net.sh
- KEYBINDINGS.md, docs/HARDWARE.md, CHANGELOG.md

## Steps
1. Glyphs per block; verified present in CascadiaCodeNF.ttf (fc-query).
2. Compact values: DISK no "free", TEMP "°", MEM used only, NET no SSID,
   MIC/VOL/BT icon alone when muted/off, BAT charging icon replaces "+".
3. Update the tests' expected strings.
4. Update KEYBINDINGS.md bar table + prose, HARDWARE.md, CHANGELOG.

## Out of scope
- dwm-clock, dwm-dnd (already an icon), blocks.def.h signal table.

## Risks
- GAMMA vs BL distinction (docs: no false power-saving claim) — gamma keeps
  the sun 󰃟, a real backlight gets the lamp 󰛨.
