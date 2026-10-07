# Scope F — Desktop integration pass

Opened 2026-10-07 from a whole-desktop survey (keybinds, autostart, bar,
package lists, doctor). Theme: pieces that are installed but not linked to
each other. CI was green on `main` (`d7e7f2b`) when this opened.

## Locked decisions (user, 2026-10-07)

1. **Items in scope:** F1 F2 F3 F4 F5 I1 I2 I3 I4 I5 A1 A2 (survey ids below).
   Out: I6 (doctor live-daemon check — unless slot 3 finds `check_daemons`
   does not already cover it), A3 (SECURITY/SPEC/RELEASING docs), A4 (bare metal).
2. **I5 — nm-applet is autostarted**, guarded like blueman-applet (only when
   NetworkManager runs). The NET block keeps `nmtui` on click. Three-place
   autostart change per CLAUDE.md rule 6.
3. **F1 — the `Firefox` rule is deleted**, not fixed. Firefox opens on the
   current tag like everything else.
4. **Keys:** `Super+grave` = scratchpad terminal (A1). `Super+Shift+n` =
   dunst do-not-disturb toggle, `Super+Ctrl+n` = notification history-pop
   (I1). MODKEY is Alt (Mod1), so all three are free in dwm; check sxhkdrc
   and `config.def.h` again before binding — dwm and sxhkd must stay disjoint.
5. **Four slots, in order**, each with its own review and commit:
   1. `dwm-rules-scratchpad` — F1 + F2 + A1 + F5 (one dwm rebuild; C sources
      + `PATCHES.md`/diff per rule 5 if a patched behaviour changes)
   2. `bar-integration` — I2 + I3 + I4 + A2 (block scripts + tests for the
      11 untested ones, fake binaries on PATH)
   3. `session-integration` — F3 + I1 + I5 (autostart, sxhkd, xdg-user-dirs,
      dunst DND bar indicator; `dwm-keys` cheat sheet and KEYBINDINGS.md)
   4. `vm-verify` — F4: today's three open VM checks plus everything above,
      on the Fedora VM (`ssh ysf@192.168.122.2`)

## Survey items

- **F1** dead `Firefox` rule in `rules[]` (stock example, case-sensitive class).
- **F2** no floating rules: pavucontrol, blueman-manager, nmtui terminal,
  gpick, file-roller, lxpolkit dialog. Real WM_CLASS values to be read with
  `xprop`, not guessed.
- **F3** `xdg-user-dirs` installed, never run (dwm skips `/etc/xdg/autostart`);
  `dwm-screenshot`/`dwm-record` hardcode `~/Pictures`/`~/Videos`.
- **F4** open VM checks from 2026-10-07 logs: clipmenud `.xinitrc` paste,
  bar after quick re-login, cursor size across login; floating tray icons'
  owner.
- **F5** windows recovered by `scan()` after restart lose dwm's selected
  client (from `2026-10-06-ci-dwm-runtime-red.md`).
- **I1** dunst history (20) has no key; no DND toggle or bar indicator.
- **I2** scroll on vol block shows no `dwm-osd`; brightness block takes no
  clicks/scroll.
- **I3** cpu/mem/temp/brightness blocks take no clicks.
- **I4** updates block click only lists; add right-click upgrade in a
  terminal + refresh signal.
- **I5** see decision 2.
- **A1** see decision 4. dynamicscratchpads only adopts an existing window —
  /explore decides between a dwm-side spawn-or-toggle and an sxhkd script.
- **A2** tests for the 11 block scripts without one (only `dwm-net` has one).

## Open for /explore (slot 1)

- Real WM_CLASS of each F2 tool on Fedora 44 (VM `xprop`).
- A1 mechanism; must not collide with dynamicscratchpads' tag bit.
- F5: reproduce under `tests/dwm-runtime.sh` before touching `scan()`.

## Explore outcome, slot 1 (2026-10-07) — appended, not interleaved

RECLASSIFICATION of F5 (Small bug → the main item of slot 1). Its cause is not
`scan()` alone: `scripts/theme/reload.sh` `reload_dwm` SIGHUPs dwm on **every**
wallpaper change and theme switch, restartsig re-execs, and `dwm.c` keeps no
per-window state — `manage()` → `applyrules()` gives every recovered window the
current tagset. So each Super+w collapses all windows onto one tag, un-stashes
scratchpads (SCRATCHPAD_MASK lost) and drops focus. The focus loss the
2026-10-06 log recorded is one symptom of this.

6. **F5 fix = upstream `preserveonrestart`** (user, 2026-10-07): tags + monitor
   stored in an X property on each client, read back in `manage()`; extended to
   keep SCRATCHPAD_MASK and restore the focused client. Vendored as a
   `*-local.diff` + `PATCHES.md` entry (rule 5). Rejected: stopping the restart
   (bigger C change, manual restart still scatters) and focus-only.
7. **A1 lives in dwm** (user, 2026-10-07): `Mod4+grave` → spawn
   `alacritty --class dots-dropterm` if absent, else toggle it in/out of
   SCRATCHPAD_MASK. Rejected: sxhkd + xdotool map/unmap (outside the
   dynamicscratchpads cycle, flicker).
8. **Tests:** both under Xvfb in `tests/dwm-runtime.sh`'s harness — restart
   then assert tags/scratchpad/focus held; dropterm spawn/hide/show.

### F2 WM_CLASS, read on the Fedora 44 VM with xprop (2026-10-07)

| tool | instance, class | window type | rule needed |
| ---- | --------------- | ----------- | ----------- |
| pavucontrol | `pavucontrol`, `pavucontrol` | NORMAL | yes |
| gpick | `gpick`, `Gpick` | NORMAL | yes |
| file-roller | `org.gnome.FileRoller` ×2 | NORMAL | yes |
| nm-connection-editor | `nm-connection-editor`, `Nm-connection-editor` | NORMAL | yes (nm-applet's editor, I5) |
| blueman-manager | `blueman-manager`, `Blueman-manager` | **DIALOG** | no — `updatewindowtype()` already floats DIALOG |
| nmtui terminal | set by us: `alacritty --class dots-nmtui` (dwm-net change) | — | yes |
| firefox | `Navigator`, **`org.mozilla.firefox`** | NORMAL | confirms F1: the `"Firefox"` rule never matched |

lxpolkit's dialog could not be raised over ssh (pkexec asks the caller's
session's agent). GtkDialog is DIALOG-typed, so it should already float —
verify with `pkexec true` inside the VM session in slot 4.

## Explore outcome, slot 3 (2026-10-07) — appended, not interleaved

9. **I1 DND indicator = a new 12th dwmblocks block** (user): prints a muted
   `DND` only while dunst is paused, nothing otherwise. Super+Shift+n signals
   it. Existing installs need `rm suckless/dwmblocks/blocks.h` + rebuild
   (the NET precedent). Rejected: clock marker, notification only.
10. **F3: `xdg-user-dirs-update` runs at every login from autostart.sh**
    (user) — Fedora's own behaviour; a rule-6 three-place change like a
    daemon (one-shot: the doctor already reports those as "runs once at
    login"). dwm-screenshot/dwm-record ask `xdg-user-dir PICTURES/VIDEOS`.
    Rejected: once at install.
11. **I6 is mostly already done**: `dots doctor` reads its daemon list from
    the autostart report, so sxhkd/dwmblocks are checked and nm-applet will
    be. The gap is dunst (D-Bus activated, never in autostart): slot 3 adds a
    doctor check that it answers, and warns while it is paused.
