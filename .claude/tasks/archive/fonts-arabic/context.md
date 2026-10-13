# Context — fonts-arabic

## Background
User request 2026-10-13: "work on fonts and fontconfig, mainly arabic and english; keyboard qwerty only".

## Prior Decisions
User answers 2026-10-13: Noto Sans Arabic; patch dwm+dmenu with fribidi; accept terminal limit; GTK UI font Noto Sans 10.

## References
- https://dwm.suckless.org/patches/bidi/ (dwm-bidi-restricted-20230512-e81f17d.diff)
- https://tools.suckless.org/dmenu/patches/bidi/ (dmenu-bidi-20210723-b34d318.diff)
- mdapi f43+f44: google-noto-sans-arabic-vf-fonts, google-noto-naskh-arabic-vf-fonts, fribidi-devel all 200; mlterm absent.
- cascadia-code-nf-fonts 2407.24 (f43/f44) — Arabic glyphs since 2404.

## Notes
fribidi_log2vis applies FRIBIDI_FLAGS_ARABIC (joining + presentation-form shaping).
