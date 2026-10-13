# fonts-arabic
Date: 2026-10-13
Files: 35 | Lines: +1230/-37 (approx.; the log, task-folder archive and state reset are included)

## What changed
- **Packages.** `desktop.lst`: `google-noto-sans-arabic-vf-fonts`, `google-noto-naskh-arabic-vf-fonts` (with consequence text). `extra.lst`: `google-noto-serif-vf-fonts`, `google-noto-sans-mono-vf-fonts`; the `jetbrains-mono-fonts-all` comment now says nothing references it. `build.lst`: `fribidi-devel`; `install-suckless.sh` pacman/apt fallbacks gained `fribidi` / `libfribidi-dev`.
- **`config/fontconfig/fonts.conf`** (new, linked to `~/.config/fontconfig` by `symlinks.sh`): each generic lists its Latin face, then the Noto Arabic face (`sans-serif` Noto Sans → Noto Sans Arabic, `serif` Noto Serif → Noto Naskh Arabic, `monospace` Cascadia Code NF → Noto Sans Mono → Noto Sans Arabic). A `lang=ar` rule puts the Arabic face first using `prepend_first`. Rendering rules match the xsettingsd `Xft/*` keys. The `install-restore-flatpak.sh` comment no longer says "dots ships no fontconfig".
- **`themes/*/theme.conf`**: `font=Noto Sans 10` (was JetBrains Mono 10).
- **dwm** (`dwm-bidi-20261013-local.diff`): `bidi()` passes the window title through fribidi's `fribidi_log2vis`, which reorders it into visual order and shapes Arabic. The buffers are hardened (see Decisions) and pure ASCII skips the work. `config.mk` links fribidi, and `fonts[]` gains `"Noto Sans Arabic:size=10"` as its second entry.
- **dmenu** (`dmenu-bidi-20261013-local.diff`): the same for items and the input line. Input is capped at `BIDI_MAX` and the buffers are static. `fonts[]` gains the same Arabic entry, which `-fn` does not replace.
- **Tests:**
  - `tests/fontconfig-stack.sh`: every family named anywhere (fonts.conf, the three `config.def.h`, alacritty, theme.conf) maps through `FAMILY_PKG` to a declared package. It also checks the symlinks.sh link and the generic + `lang=ar` + codepoint resolutions under the host's real fontconfig with sandboxed XDG dirs.
  - `tests/bidi.sh`: extracts the shipped `bidi()` from dwm.c and dmenu.c, compiles it under ASan, and checks shaping, visual order, the ASCII identity, the buffer caps and the draw sites. CI build-suckless installs `libasan` and runs it as `--strict`.
- **Docs:** `docs/FONTS.md` (new), TESTING.md entries, CHANGELOG [Unreleased] (Added + Changed), the CLAUDE.md map and patch roster (dwm 18, dmenu 10), and the PATCHES.md entries. The scope-b decision 14 entry now carries a superseded note.

## Why
The user reads Arabic and English and types QWERTY only. Before this change the repo shipped no Arabic font and no fontconfig, so Arabic fell to whatever the system ranked next, often tofu on Server. Xft in dwm/dmenu also drew Arabic as isolated letters in reverse order.

## Key Technical Decisions
- **DECISION REVERSAL — the UI font.** Scope B locked decision 14 ("JetBrains Mono stays for UI surfaces"). On 2026-10-13 the user chose Noto Sans 10 for GTK when asked. The scope-b file is annotated (appended, not rewritten). `jetbrains-mono-fonts-all` stays installed, with no consumer.
- **User decisions 2026-10-13:**
  - Arabic face: Noto Sans Arabic (over Vazirmatn / IBM Plex Sans Arabic).
  - dwm + dmenu: patched with fribidi.
  - Terminals: the no-shaping limit is accepted and documented (over a VTE terminal or an experimental st patch).
  - UI font: Noto Sans 10.
- **Hardened upstream bidi patches.** Both upstream patches write the output into a buffer the size of the input. Arabic letters (2 bytes) shape into presentation forms (3 bytes), so long titles overflow it. Under ASan the upstream 256-byte size is a global-buffer-overflow on a 400-byte title; the fix sizes the output at 4 bytes per codepoint. The input copy is zero-padded because fribidi's UTF-8 decoder reads continuation bytes without a length check, and `strlen` is capped as `size_t` before narrowing to `FriBidiStrIndex`.
- **The Arabic face is named explicitly in `fonts[]`.** Cascadia Code NF 2407.24 carries U+06xx but not Presentation Forms-B (U+FE70–FEFF), which is what the shaping emits. Without the explicit entry, fontconfig's per-glyph fallback would decide.
- **Noto Sans Mono sits in the monospace alias** so a box without Cascadia gets a monospace Latin face, not the proportional Arabic one. It is listed ahead of the Arabic face.
- **Emoji are left out of fonts.conf.** `google-noto-emoji-fonts` is the monochrome Noto Emoji, and dmenu's config warns that a colour emoji fallback crashes it.

## Assumptions Made
- (Type B) "QWERTY only" means no Arabic XKB layout or layout switch. It is out of scope.
- (Type B) Bidi applies to the window title only, not to the status blocks or tags, which are ASCII + Nerd glyphs.
- (Type C) The `bidi()` helper is duplicated in dwm.c and dmenu.c. Each suckless program is self-contained, which follows the existing patch practice.

## Test coverage
- `tests/run-tests.sh`: exit 0, 59 scripts OK (build/lint/run-tests skipped by design). Also passing: `tests/lint.sh`, `tests/build.sh`, `tests/bidi.sh --strict` (ASan), and `tests/dwm-runtime.sh` against the patched dwm.
- Mutation-tested on scratch copies, never the worktree:
  - fontconfig-stack caught 7 of 7 (prepend vs prepend_first, broken XML, package dropped, unmapped family, theme typo, link removed, mono alias losing the Arabic face).
  - bidi caught 6 of 6 (upstream buffer size in dwm and in dmenu, no ASCII fast path, no length cap, title not drawn through bidi(), input not drawn through bidi()). The overflows were caught by ASan.
- Visual checks under Xvfb with screenshots on the Arch dev host: dmenu items and the dwm title render joined and RTL, and mixed lines follow the UBA.
- Flatpak checked on the dev host (Flatpak 1.18.4, an installed app): `xdg-config/fontconfig:ro` follows the symlink and mounts fonts.conf into the app's config dir, and the sandboxed fontconfig loads it.
- Package names checked against mdapi.fedoraproject.org for f43 and f44 (pkg + file lists). mlterm is absent from Fedora; libasan is present.
- **Not run on Fedora.** The VM was unreachable because its ssh agent key was not loaded.

## Follow-ups
- Check on the Fedora 44 VM: rebuild suckless, run `dots theme dark`, open an Arabic page in Firefox and give a window an Arabic title. Confirm `fc-match 'sans-serif:lang=ar'` returns Noto Sans Arabic.
- Optional: a `dots doctor` check that the Arabic faces are installed and resolve.
- Optional: decide whether `jetbrains-mono-fonts-all` stays now that nothing references it.
