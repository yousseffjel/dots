# Scope D — verification harvest from the dwm-titus reference clone

Epic decomposition per `.claude/rules/foundations/task-planning.md` §
"Any -> Epic". Source request: user, 2026-08-24, in-chat — "lets start on
#1 + #2 + #3 + #6" against the ranked harvest table in
`.claude/changes/2026-08-24-dwm-titus-reference-clone.md`.

Reference source: `dwm-titus/` at HEAD `e1f884e` (CLAUDE.md rule 9 — read
only, never referenced from a script, never assumed present). Nothing here
is a port. Every item below is an **idea** taken from that clone and
re-derived against this repo's own shape; the clone's implementations
assume a hard-forked `dwm.c`, a `make install` flow and a Qt6 shell, none
of which exist here.

**The through-line: this repo verifies its inputs and has never verified an
output.** Package names are checked against a web page, scripts are linted,
templates are diffed — and the two bugs that reached real machines
(`$USER` unbound, `systemctl enable ly.service` naming a unit Fedora does
not ship) both survived every one of those because nothing ever ran the
line. All four sub-tasks buy output verification.

---

## Locked decisions (do not re-litigate)

1. **Four sequential slots, in the order A -> B -> C -> D.** Chosen by the
   user over two-slot, one-slot and fully-parallel alternatives. A closes a
   live drift bug immediately; B is infrastructure C depends on; C is the
   highest-value item; D is the most environment-sensitive and goes last.
   Each slot gets its own audit, reviewer gate and dated change log.
2. **Slot B ports process-group safety and workspace handling — not the
   runner token.** Chosen by the user. `setsid` on the child, refusal of
   `/`, `/tmp` and symlinked test roots, an `mktemp` workspace cleaned on
   every exit path, `TMPDIR` exported into the tests. dwm-titus's
   per-run random token and root/EUID branches exist for its
   container-as-root and privileged-helper tests; this repo has neither, so
   carrying them would be machinery for a case that does not occur.
3. **Slot C extends the existing `build-suckless` CI job rather than adding
   a new one.** That job already builds dwm in a Fedora container on both
   matrix legs; it needs `xorg-x11-server-Xvfb` and `xprop` and it is the
   Xvfb test's environment. A separate job would rebuild dwm to get there.
4. **Slot C asserts the vendored patches, not just vanilla dwm.** 23
   `.diff` files have no test of any kind. `_NET_SUPPORTED`,
   `_NET_CLIENT_LIST`, `_NET_ACTIVE_WINDOW`, `_NET_SUPPORTING_WM_CHECK`
   and `_NET_WM_STATE_FULLSCREEN` are all present in
   `suckless/dwm/dwm.c`; xresources, pertag, hide_vacant_tags, restartsig
   and actualfullscreen are the patch behaviours worth reaching. The
   xresources one matters most — it is the theming engine's entire runtime
   contract, currently proven only as far as template rendering.
5. **Slot D proves symmetry against the manifest, not against a
   hand-written expected list.** `$XDG_STATE_HOME/dots/manifest` is
   already the installer's record of what it created and already what
   `uninstall.sh` acts on. The test asserts round-trip: snapshot the
   sandboxed `$HOME`, run the restore stage, snapshot, run uninstall,
   snapshot, and require the third to equal the first. A hand-written
   expected list would be a second declaration and would rot.
6. **All four XDG variables must be set in any sandboxed-`$HOME` test.**
   `HOME=` alone leaks into the real manifest, which `uninstall.sh` then
   acts on. This is a recorded incident, not a hypothetical.
7. **The `patch` / rule-5 contradiction is OUT of slot A's scope.** Decided
   by the user, 2026-08-24, over correcting it inside slot A. Slot A does the
   mechanical half only — CI reads the list, a guard test stops a third copy
   appearing — and the correction is its own queue item in `MASTER_PLAN.md`.
   **The consequence must not be forgotten:** `build.lst` keeps `patch`, so
   once CI reads the list it starts installing a package no shipped code path
   uses. That is knowingly wrong for as long as the queue item waits, and
   slot A's change log must say so rather than presenting the two lists as
   simply reconciled.

   The finding itself, for the queue item to work from: **no build-time patch
   step exists anywhere in this repo.** No `patch(1)` or `git apply`
   invocation in `scripts/`, `tests/`, `.github/` or any suckless `Makefile`;
   all four `suckless/*/patches/PATCHES.md` state the sources are pre-patched
   ("already baked into `dwm.c`/`config.def.h`", and the newer entries are
   "not a verbatim `patch -p1` apply — hand-merged into the already-patched
   sources"); and `suckless/dwm/dwm.c` carries the systray enum and
   `enum XResType` in-tree. Rebuilding a real patch flow is not a third
   option — `PATCHES.md` records that the `*-local.diff` files exist
   precisely because they could not apply cleanly on top of the others.

8. **Slot D must not invoke the theming engine's post-commands.**
   `apply-templates.sh` post-commands `pkill` dunst and dwmblocks
   system-wide; environment sandboxing cannot contain that. Recorded
   hazard.

---

## Sub-tasks

- [ ] **A — CI build dependencies from `packages/build.lst`** (#3, Small)
      `.github/workflows/ci.yml`'s `build-suckless` job hardcodes 12 dnf
      package names under a comment claiming it "Matches the dnf branch of
      scripts/install-suckless.sh's install_deps() exactly". **It does
      not** — `build.lst` declares 13, and the one missing from CI is
      `patch`, which applies every vendored `.diff` (CLAUDE.md rule 5).
      CI has never needed it because `tests/build.sh` runs `make` only,
      never the patch step, so the comment has been false and unnoticed.
      Read the list instead of restating it, and guard the coupling with a
      test so a third copy cannot appear. **Scope is the mechanical half
      only** — see locked decision 7 for what is deliberately left undone
      and why the two lists agreeing does not mean they are right.
      Exit: CI installs exactly what `build.lst` declares; a test fails the
      build if any consumer restates the names; both matrix legs green; the
      change log states that `patch` is still declared and still unused.

- [ ] **B — a real test runner** (#6, Small–Medium)
      There is no runner. `ci.yml` inlines a `for t in tests/*.sh` loop,
      `TESTING.md` documents a hand-copied version of the same loop, and
      `/test` has failed to discover this suite in four separate logged
      sessions because no `.claude/config.yml` names one. Add
      `tests/run-tests.sh` owning the glob, the skip list and the
      pass/fail report, with the decision-2 hardening. CI and TESTING.md
      then invoke it rather than restating it.
      Exit: one owner for the loop; `/test` discovers the suite; an
      interrupted run leaves no orphaned child process.

- [ ] **C — dwm under Xvfb** (#1, Medium–High)
      New `tests/dwm-runtime.sh`: start Xvfb, run the built dwm against it,
      assert real EWMH state and the patch behaviours from decision 4.
      Wired into `build-suckless` per decision 3.
      Exit: dwm is executed by CI for the first time; at least the
      xresources colour path and one pertag behaviour are asserted against
      a running instance; deliberate mutations of each are caught.

- [ ] **D — install/uninstall symmetry** (#2, Medium)
      New test proving the round-trip of decision 5 in a sandboxed `$HOME`
      honouring decisions 6 and 7.
      Exit: every path the restore stage creates is manifest-claimed, and
      `uninstall.sh` returns the tree to its pre-install state; a
      deliberately unclaimed path fails the test.

---

## Out of scope

- Runtime TOML config with hot reload (harvest item #4). It is the largest
  idea in the clone and a genuine Epic of its own — it means linking a
  parser into dwm and retiring part of `config.def.h`. Not queued; the
  user has not decided whether it is wanted at all.
- Quickshell / Qt6, the hard-fork model, kickstart ISOs, and dwm-titus's
  hand-written `themes.toml` palettes. All rejected in the 2026-08-24
  assessment; see that change log for why.
- Harvest items #5 (dual-format diagnostics) and #7 (CHANGELOG /
  CONTRIBUTING / SECURITY / Dependabot). #7 is already two open
  framework-parity queue items in `MASTER_PLAN.md` and stays there.
