# 2026-08-04 — Static analysis + sanitizer audit across dwm, st, dwmblocks, dmenu

## Scope

- `suckless/dwm/dwm.c`, `suckless/dwm/util.h`
- `suckless/dmenu/dmenu.c`, `suckless/dmenu/util.h`
- `suckless/st/st.h`
- `suckless/dwmblocks/**` — audited, clean, no changes
- Build files modified temporarily only; all restored (md5-verified against
  pre-modification copies)

All four objectives ran. `cppcheck` 2.21.1 and `clang`/`scan-build` 22.1.8 were
installed mid-task by the user.

## Headline result

Two heap buffer overflows, one use-after-free / double-free, one list-corruption
bug, one shift UB, and four format-string UBs fixed. Analyzer findings dropped
from **38 → 19** (scan-build) and **18 → 7** (cppcheck error/warning/portability).

## Defects fixed

### 1. Heap over-read in dwm `drawstatusbar()` — `dwm.c:933-980` — highest severity

The status2d colour-code parser scans and copies without bounds:

```c
while (text[++i] != '^') {              /* no NUL test: scans off the end */
        if (text[i] == 'c') {
                char buf[8];
                memcpy(buf, (char*)text+i+1, 7);   /* no remaining-length test */
```

`text` is an exact-size heap copy of the status string, which comes from the X
root window name — set by dwmblocks, but writable by **any X client on the
display**. Two distinct over-reads, both trivially reachable:

| Input | Over-read |
|-------|-----------|
| `^c#12`, `^c` | `memcpy` READ of size 7 past the allocation |
| `^cAAAAAAA`, `ok^r1,2,3`, `^r1,2`, `^` | unbounded byte scan past the NUL |

Fixed by NUL-terminating every scan (`^` code scan and the three `,` scans in
the `r` branch), bounds-checking both `memcpy`s against an absolute `end`
pointer, and breaking out of the outer loop on an unterminated code. The `c` and
`b` branches were merged since they differed only in target scheme field.

Under ASan, 7 of 8 probe inputs overflow before; 13 of 13 clean after.

### 2. Heap overflow in dmenu `fuzzymatch()` — `dmenu.c:343`

```c
for (i = 0, it = fuzzymatches[i]; i < number_of_matches && it &&
        it->text; ++i, it = fuzzymatches[i])
```

The increment `it = fuzzymatches[i]` runs **before** the `i < number_of_matches`
test, so the final iteration reads `fuzzymatches[number_of_matches]` — one
pointer past a `malloc(number_of_matches * sizeof(struct item *))`. Verbatim
upstream fuzzymatch-patch code. Triggers on any fuzzy search producing ≥1 match.

Rewritten to index before dereferencing. Found by **ASan at runtime**, not by
any static analyzer.

### 3. Use-after-free + double-free in dwm `autostart_exec()` — `dwm.c:1859-1877`

Both `sprintf` failure branches `free(path)` / `free(pathpfx)` and then **fall
through without returning**. Every subsequent `access()`, `system()` and
`strcat()` is a use-after-free, and the two trailing `free()`s are double-frees.
Lines 1834, 1846 and 1852 in the same function all correctly `return` after
freeing, so this is an oversight in the autostart patch.

Flagged independently by cppcheck (`deallocuse` ×4, `doubleFree` ×4) and
scan-build (`Use of memory after it is released`). Fixed by adding the missing
`return;`.

### 4. Systray list corruption in dwm `removesystrayicon()` — `dwm.c:1646`

```c
for (ii = &systray->icons; *ii && *ii != i; ii = &(*ii)->next);
if (ii)          /* always true - ii is the address of a link */
        *ii = i->next;
```

`ii` is a `Client **` and is never NULL, so the guard is dead. If the icon is
not in the list the loop stops at the tail's `next` with `*ii == NULL`, and the
assignment splices `i`'s successor onto the tail. Changed to `if (*ii)`.

### 5. Shift UB in dwm `tagview` pertag logic — `dwm.c:2355`

`curtag` is `unsigned int` and is set to `0` immediately above on the all-tags
view, so `1 << (curtag - 1)` shifts by `UINT_MAX`. clang reported it exactly:
*"right operand '4294967295' is not smaller than 32"*. Guarded with
`selmon->pertag->curtag &&`.

### 6. Format-string UB — 4 sites

`%u` applied to `size_t` (varargs mismatch: `%u` consumes 4 bytes, `size_t`
passes 8), and `%d` applied to `unsigned int`:

| File | Line | Was |
|------|------|-----|
| `dmenu/dmenu.c` | 336 | `%u` ← `size_t` |
| `dwm/dwm.c` | 639 | `%u` ← `sizeof(Client)` |
| `dwm/dwm.c` | 2707 | `%u` ← `sizeof(Systray)` |
| `dwm/dwm.c` | 1472 | `%d` ← `unsigned int n` |

### 7. `die()` declared `noreturn` + `format(printf)` — `dwm/util.h`, `dmenu/util.h`, `st/st.h`

`die()` always `exit(1)`s but was declared plain `void`. Consequences measured:

- Static analyzers treated every `if (!(p = malloc(..))) die(..);` as a path
  where `p` may still be NULL → **6 false positives in dwm alone**
  (scan-build 17 → 11 on this change alone).
- `-Wformat` never checked its arguments, which is why all four format bugs
  above survived a `-Wall` build.
- Caused the bogus `-Wimplicit-fallthrough` on `st.c:836`'s `case -1: die(..)`
  (st strict warnings 50 → 49).

Guarded with `#if defined(__GNUC__) || defined(__clang__)` so non-GNU compilers
still build. After the change, all four trees compile with **zero** warnings at
production flags — confirming no format bugs remain anywhere.

## Findings deliberately NOT fixed

| Finding | Count | Why |
|---------|-------|-----|
| `-Wextra` sign-compare / unused-parameter / missing-field-initializers | 87 | Inherent to the suckless idiom and Xlib's API shape. Silencing means casts that hide future real sign bugs, or `(void)arg;` in ~15 signature-fixed callbacks. Production flags (`-Wall`) are warning-clean. |
| cppcheck `memleakOnRealloc` (`tokv`, `items`) | 2 | Both immediately `die()` on failure; the process exits. Not reachable leaks. |
| gcc `-fanalyzer` leak of `tokv` (`dmenu.c:370`) | 1 | False positive — `tokv`/`tokn` are `static`, cached across calls by design. gcc loses static storage duration through the `match.part.0` partial-inline clone. |
| cppcheck `nullPointerRedundantCheck` (dmenu `sel`/`item`) | 3 | `item` is the loop variable and always non-NULL; the `if (sel)` after `sel = item` is redundant but harmless. |
| cppcheck `uninitvar` `st.c:2074` | 1 | Benign — `tprinter(buf, utf8encode(bp->u, buf))`; both args are evaluated before the call, so `utf8encode` fills `buf` first. When it returns 0, `xwrite` reads 0 bytes. |
| cppcheck `UnionZeroInit` `dwm.c:496` | 1 | `Arg arg = {0}` where the union's largest member isn't first. Fixing means reordering the config-facing `Arg` union, which would break every user `config.h`. Out of scope. |
| cppcheck `unknownMacro` `x.c:2084` | 1 | False positive — cleared by passing `-DVERSION`. |
| scan-build `Division by zero` `dwm.c:2272` | 1 | Infeasible — `i` counts tiled clients so `i < MIN(n, nmaster)` holds in that branch; denominator ≥ 1. |

### Unresolved

**`scan-build: Use of memory after it is released` — `dwm.c:588`** (in `cleanup()`).
`detachstack()` sets `*tc = c->snext`, so `m->stack` is updated to the next
client before `free(c)` and the `while (m->stack)` re-read sees the new head.
I believe this is a false positive — clang losing track through the
pointer-to-pointer walk — but I did **not** prove it, and it survived every fix.
Unchanged upstream dwm 6.8 code, runs only at shutdown. Worth a second look.

## Verification

| Check | Before | After |
|-------|--------|-------|
| Production build, all 4 | 0 warnings | 0 warnings |
| `-Wall -Wextra -Wpedantic` | dwm 33 / st 50 / dwmblocks 0 / dmenu 5 | dwm 33 / st **49** / dwmblocks 0 / dmenu 5 |
| gcc `-fanalyzer` | 1 (false positive) | 1 (same) |
| **cppcheck** err+warn+port | dwm 11 / st 2 / dwmblocks 0 / dmenu 5 | dwm **1** / st **1** / dwmblocks 0 / dmenu 5 |
| **scan-build** | dwm 21 / st 7 / dwmblocks 0 / dmenu 10 = **38** | dwm **11** / st **2** / dwmblocks 0 / dmenu **6** = **19** |
| ASan+UBSan build, all 5 binaries | exit 0, instrumented | exit 0, instrumented (26–34 syms each) |
| `stest` under ASan+UBSan | clean | clean |
| `dwmblocks-nox` under ASan+UBSan | clean | clean |
| dmenu under ASan+UBSan | **caught fuzzymatch overflow** | — |
| `drawstatusbar` parser, isolated ASan harness | 7/8 inputs overflow | **13/13 clean** |
| `fuzzymatch` loop, isolated ASan harness | `heap-buffer-overflow READ of size 8` | clean, all items appended |
| Build files after revert | — | md5 MATCH ×4; `git diff` shows only `.c`/`.h` |
| Final binaries | — | 0 sanitizer symbols |

## Assumptions made

- **Type B — added `noreturn`/`format` attributes to `die()`.** Not literally a
  leak or buffer fix, but it eliminated 6 false positives, is what allowed
  `-Wformat` to prove the format fixes complete, and prevents the whole bug
  class recurring. Guarded for non-GNU compilers. *If unwanted:* delete the
  7-line block in each of `dwm/util.h`, `dmenu/util.h`, `st/st.h` — nothing else
  depends on it.
- **Type B — fixed upstream bugs in-tree rather than reporting them.** Every
  defect except #5 is upstream/patch code, not introduced by vendoring. This
  tree already carries five hand-merged dmenu patches, so local correction is
  consistent with how it is maintained. *If wrong:* each fix is an isolated hunk.
- **Type C — `drawstatusbar` `c`/`b` branches merged.** They differed only in
  which scheme field they target; merging avoids duplicating the new bounds
  check. Behaviour is identical.

## Trade-offs

- **The most serious bugs came from running instrumented binaries, not from
  static analysis.** The dmenu overflow was found by ASan; neither cppcheck,
  scan-build, nor `-fanalyzer` flagged `fuzzymatch()` at all. Static analysis
  found the dwm autostart UAF and the shift UB, which ASan would never have
  reached without a WM session.
- **dwm and st have no instrumented runtime coverage.** Their ASan builds are
  verified but neither was run. dwm is a window manager — starting it on the
  live `:1` would take over the session. `Xvfb` is not installed.
- **`drawstatusbar` was not exercised in a live dwm.** The fix is proven by an
  isolated harness that mirrors the loop verbatim, and dwm builds and links
  clean, but no status bar has actually been rendered with the new parser.
- **A malformed-but-full-length colour code still kills dwm.** `^cZZZZZZZ^`
  passes the new bounds check, reaches `drw_clr_create`, and `die()`s on
  `XftColorAllocName` failure (`drw.c:178`). Pre-existing upstream behaviour,
  out of scope here, but it is a root-window-triggerable DoS.

## Next steps

1. **Render a status bar under a real dwm** to confirm `drawstatusbar` still
   draws correctly — the highest-value untested change. `dwmblocks` output uses
   `^c#RRGGBB^` codes, so a normal session exercises it immediately.
2. Re-verify dmenu fuzzy matching (`-F`) interactively on the target.
3. Resolve or dismiss the `dwm.c:588` scan-build use-after-free.
4. Install `Xvfb` for isolated instrumented runtime coverage of `st` and `dwm`.
5. Consider making `drw_clr_create` fall back to a default colour instead of
   `die()`ing, closing the root-window DoS noted above.

## Protocol note

`xdotool` was used briefly to drive dmenu under ASan; it sends keystrokes to the
focused window and leaked input into the user's live session (one stray `tem1`).
Abandoned after one use — all subsequent verification used isolated harnesses.
Do not drive GUI programs this way on a live display.
