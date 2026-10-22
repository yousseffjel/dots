# screenshot-dropdown
Date: 2026-10-22
Files: 18 | Lines: +629/-21 (code, tests, a 200-line captured fixture, docs; plus this log and state)

## What changed
- The region screenshot key moved from `Super` + `p` to `Super` + `a` (user:
  one-handed), and it no longer closes an open browser dropdown.
- New daemon `config/dwm/bin/dwm-shotkey`: reads Super+a from
  `xinput test-xi2 --root` raw events (NO key grab), fires only with nothing
  but Super held, ignores autorepeat and a second press while a shot runs,
  looks keycodes up with `xmodmap -pke` (evdev fallbacks), runs
  `dwm-screenshot --region --clipboard --no-grab`, and kills slop on Escape.
  Wired as an autostart daemon in all three places (template, report,
  tests/autostart-daemons.sh) plus a doctor-daemons case (needs xinput).
- `dwm-screenshot`: `--no-grab` (slop `--nokeyboard`) and `--delay N`
  (notify, sleep, then capture). Region mode now captures the whole screen
  first and crops slop's rectangle out with ImageMagick (`magick`, else
  `convert`), so the image is the screen at the keypress.
- sxhkdrc: `super + a` deliberately NOT bound (a grab would come back);
  `super + shift + a` = `--delay 3 --region --clipboard`.
- st `config.def.h`: `{ Mod4Mask, XK_a, ttysend, {.s = ""} }`; alacritty:
  `[keyboard]` binding Super+A → `None`. Both would otherwise type an "a",
  since an ungrabbed key also reaches the focused window.
- `xinput` moved from extra.lst to desktop.lst (with consequence text).
- Tests: new tests/dwm-shotkey.sh over a real captured xinput stream
  (tests/fixtures/xinput-test-xi2-super-a-escape.txt) plus synthetic ones;
  tests/dwm-screenshot.sh covers freeze order, the crop, --no-grab,
  --delay, and missing ImageMagick. KEYBINDINGS.md, CHANGELOG, CLAUDE.md map.
- The user's own `~/.local/share/dwm/autostart.sh` got the launch line, at
  their request (it is user-owned; the installer never edits it).

## Why
User: opening a dropdown and pressing the screenshot key closed it. Two
attempts failed before the cause was measured. Freeze-then-crop alone did not
help, and neither did a 3 s delay. A Firefox page logging `blur`/`focus` in
Xvfb settled it: sxhkd's passive grab and slop's keyboard grab each fire
`blur` (FocusOut, NotifyGrab), and the page closes its dropdown on that. An
ungrabbed key and `slop --nokeyboard` fire nothing. Any grabbed hotkey
(sxhkd, dwm, XI2 grabs) does the same, so the only fix is no grab. The user
chose "listener + terminal fix" over listener-only or reverting.

## Assumptions Made
- Type B: the freeze-then-crop stays even though `--nokeyboard` alone keeps
  the dropdown open. It is harmless, and it makes the image the screen at the
  keypress.
- Type B: `Super` + `Shift` + `a` (delay) was kept for a menu that closes on
  any keydown, even an ungrabbed one.
- Type B: Escape cancels by `pkill -x slop` (the user's), only while the
  listener's own shot is running.

## Test coverage
- Xvfb + real Firefox: the full listener → dwm-screenshot → slop -k → magick →
  xclip path produced a cropped PNG on the clipboard with no `blur`. Escape
  killed slop. Patched st and the alacritty binding typed no "a".
- The live-desktop launch found a real bug the unit tests missed:
  `already_running` counted a `setsid -f`/`timeout` wrapper and its own
  `$( )` pgrep subshell (comm bash, still alive) as another listener. Fixed
  (bash only, skip children of `$$`) and tested; a mutant without the
  bash-only filter was caught (mutated copy outside the worktree).
- First suite run: dwm-help.sh failed (no `--help`), fixed. Final
  tests/run-tests.sh rc=0; tests/lint.sh passes; reviewer READY.
- Not verified on the user's real dropdown at commit time.

## Follow-ups
- The user rebuilds st (`scripts/install-suckless.sh`, sudo) so Super+a stops
  typing an "a" there.
- Confirm on the real desktop; other browsers (Chromium) untested.
