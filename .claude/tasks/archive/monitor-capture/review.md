# Review — monitor-capture

## Audit Loop
Tier: Medium+ (12 files, +277/-28) — four sweeps.

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | One shared lib (dwm-lib-monitor.sh, 644 like its siblings) used by both capture scripts; each degrades to a stand-in that fails only --monitor when the lib is missing (screenshot's solo-copy test). Key bindings untouched (menu entry, no new grab). CHANGELOG Added, KEYBINDINGS, sxhkdrc comments, desktop.lst consequence text, CLAUDE.md map line. 0 open. |
| 2 | Size/Performance | ✅ | dwm-screenshot 191, dwm-record 189, lib 41, tests 128/215 lines. Longest touched function capture() 42 (<60). One xdotool + one xrandr call per capture. 0 open. |
| 3 | Types/Validation | ✅ | Pointer position must be numeric; monitor line must split into 6 fields; half-open edges [x, x+w); first match only (mirrored screens); no monitor → fail, never a guess; record rounds odd sizes to even; screenshot notifies on failure (key stderr is invisible). Mutants 14/14 caught after two survivors (missing-xdotool check, position check) were pinned by message asserts. 0 open. |
| 4 | Dependencies | ✅ | xdotool already desktop.lst (colour picker); its consequence text now names these modes. xrandr already desktop.lst. Tests on sealed PATH. 0 open. |

VM (2×1920x1080): with real xdotool + xrandr, pointer at 10,10 / 1919,1079 → 1920x1080+0+0 and 1920,0 / 3839,1079 → 1920x1080+1920+0 reached maim; shots 1920x1080 (full 3840x1080); `dwm-record --monitor` wrote VP9 1920x1080. Pixel comparison of the two screens was not possible: the idle lock (slock) was up and paints both alike.

Found on the way (not this slot): two screenshots in the same second share a file name and the second overwrites the first.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** none flagged.

## Test Gate
**Command:** bash tests/run-tests.sh
**Result:** ✅ PASSED (104 OK)
