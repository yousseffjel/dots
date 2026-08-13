# Handoff

Written 2026-08-08 at commit `13b6902`; **revised 2026-08-13 on top of
`fb9f075`** after several further tasks: the queue sweep, `manifest_has_path`,
xsettingsd, udiskie/autorandr, the colour picker and display menu, the first
`dwm-bin` tests, the CI Fedora pin, and the theme roster plus identity wiring.
For whoever picks this repo up next — including a future session of me.

This is deliberately **not** a summary of the other docs. It is the set of
things that are true, load-bearing, and not obvious from reading the code.

---

## Resume here — state at start of 2026-08-13

**The tree is clean and the bookkeeping is settled.** The 2026-08-12 session
left three things open and all three closed in one docs commit on top of
`fb9f075`: the uncommitted "Framework parity with HyDE" queue block in
`MASTER_PLAN.md` (six structural gaps from a fresh diff of the local HyDE clone
`8fa0073e`), the `theme-roster-identity` log folded into `CURRENT_AUDIT.md`,
and the now-done "More than one theme under `themes/`" queue bullet struck.

The lesson from that session is worth keeping, because it is the same shape the
reviewer caught *inside* the task: **this file was the stale sibling.** Its own
Resume section said "`git status` shows one modified file" while HANDOFF.md sat
modified-and-uncommitted right next to `MASTER_PLAN.md`. Writing a careful
account of everything else is exactly what makes the account itself look
reviewed. When you revise this section, `git status` first.

**An unanswered question is on the table.** `/plan` was invoked at the end of
2026-08-12 with no task named and the choice was never made. It is still open.
The candidates, in the order I would rank them:

| Candidate | Size | Why |
| --- | --- | --- |
| Container install harness | Large | Actually runs `install-fedora.sh` to completion in a `fedora:latest` container and asserts. Attacks the oldest standing risk in this repo (below). |
| tmux `@resurrect-dir` XDG fix | Small | Oldest queue item, fully specified, self-contained |
| `.claude/config.yml` `test_command` | Micro | `/test`'s discovery table matches nothing here, so every task falls through to "no test suite" despite 13 test scripts |
| Single CLI on `$PATH` | Medium | Has an unresolved design question — decide dispatcher vs symlinks first |

---

## The one-line status

A Fedora-only dotfiles + desktop bootstrap repo (dwm/X11, suckless, zsh/tmux)
that is feature-complete on paper and **has never been run end to end on real
hardware**.

That second half is the most important sentence in this document. Treat
"the installer works" as an untested hypothesis, not a fact — see
[Unproven](#what-is-genuinely-unproven).

---

## Where the truth actually lives

Read these in this order. Don't reconstruct project state from the code.

| File | What it is | Trust level |
| ---- | ---------- | ----------- |
| `CLAUDE.md` | Project map + the 10 project-specific rules | **Authoritative.** Rules are enforced by review, not by tooling. |
| `.claude/tasks/MASTER_PLAN.md` | Active / Queue / Recently Closed | **Authoritative** for what to do next |
| `.claude/changes/CURRENT_AUDIT.md` | Append-only running record, newest last | **Authoritative** for why something is the way it is |
| `.claude/changes/YYYY-MM-DD-*.md` | 45 dated logs, one per task | Full detail incl. assumptions and follow-ups |
| `ROADMAP.md` | Comparison vs. HyDE (Arch/Hyprland) | **Partly stale by design** — an idea backlog, not current state. §3 and §9 were reconciled 2026-08-12; **§5 and §7 were not** and are known-wrong (§5 still says six autostart daemons; there are nine) |
| `TESTING.md` | Per-test rationale for the 13 test scripts | Current |
| `docs/THEMING.md` | The wallpaper → palette → template engine | Current |

If a doc and the code disagree, the code wins and the doc is a bug — that has
happened repeatedly here and each instance is logged.

---

## The recurring bug shape: packaged but never launched

**Read this before adding any new tool to the desktop.** It has now happened
three times, and it is the single most productive thing to check for.

A tool gets packaged, configured, themed, tuned, documented — and nothing ever
starts it. Every layer looks correct in isolation. Nothing errors. The feature
is simply absent, and the installer reports a clean run.

1. **picom** — packaged, configured, performance-tuned across two sub-tasks,
   themed on every wallpaper change. Nothing in `autostart.sh`, `.xinitrc` or
   sxhkd launched it. Fixed 2026-08-08 (`592abb3`).
2. **sxhkd** — same class, caught earlier: it owns every non-dwm keybind and
   sat in best-effort `extra.lst`, so a failed install killed every media,
   volume, brightness, screenshot, lock and theming key at once, silently.
3. **`polkit-gnome`** — packaged, autostarted by nothing, so no polkit agent
   ran and every GUI privilege prompt failed silently. Fixed 2026-08-08. Its
   own twist: the binary is **not on `PATH`** (it lives under `libexec`, and
   Fedora and Arch disagree about where), so the obvious `command -v` guard
   copied from the other daemons would have produced a line that never fires —
   the same bug, reintroduced while fixing it. Both paths are tried.

The structural defence is in place now: the daemon set is stated twice —
`session_autostart_template()` in `scripts/install-session-template.sh` for
fresh machines (it moved out of `install-session.sh` at the 250-line cap on
2026-08-12), `session_autostart_report()` in
`scripts/install-session-report.sh` for existing ones — and
`tests/autostart-daemons.sh` fails if the two disagree. **Adding a daemon to
only one of them is the mistake that test exists to catch.** That test *runs*
both functions rather than parsing them, so restructuring either is safe; both
file splits so far needed no change to it. Nine daemons as of 2026-08-12.

**The pattern is live right now, for the fourth time.**
`network-manager-applet` and `blueman` are both declared in `extra.lst`, and
**nothing autostarts either** — no `nm-applet`, no `blueman-applet`. The dwm
systray patch is vendored and `dwm-bluetooth` is status block 9, so the tray
exists and is empty of exactly the two things a tray is for. `bluez` also
installs without `install-services.sh` ever enabling `bluetooth.service`, so
that block reports a dead stack on a fresh box. This is picom's bug, one step
further along: previously these were *absent*, now they are *packaged and
inert*. Fixing it is a three-place change per `CLAUDE.md` rule 6.

`udiskie` was in this list and is now wired (2026-08-12). `redshift` remains
undecided rather than forgotten — see `ROADMAP.md` §3's blue-light row.

---

## Landmines

Things that look safe and are not. Each was learned the hard way.

- **`config/dunst/` and `config/picom/` must never go in `symlinks.sh`.** The
  theming engine rewrites those whole files on every wallpaper change; a
  symlink would make it write into the repo. The installer copies them.
- **`config/picom/picom.conf` and `picom.dcol` must be edited together.** They
  are two copies of the same file; edit one and the next wallpaper change
  reverts your work. `tests/picom-lockstep.sh` guards this.
- **`autostart.sh` and `~/.xinitrc` are user-owned once they exist**
  (`CLAUDE.md` rule 6). The installer will never edit them — it prints the
  missing line instead. Any new daemon therefore needs a manual paste on every
  existing install, including yours.
- **Do not create `config/fastfetch/` or `config/gtk-3.0/`.** Those two configs
  are written *only* by their `.dcol` templates. Adding a static copy
  reintroduces the picom lockstep hazard.
- **The `# ### dots-theme palette ###` marker in `starship.toml` is
  load-bearing** — it is where the theming splice cuts, and the template
  refuses to touch a config without it.
- **A theme switch now writes `settings.ini` and `xsettingsd.conf`**
  (2026-08-12). `theme.conf` used to be printed and nothing more. The writers
  live in `scripts/install-restore-theme-identity.sh` and are shared by the
  installer and `theme-apply.sh`; which one is calling is expressed by
  `THEME_IDENTITY_CLOBBER` (0 = installer, never replace; 1 = switch, replace
  only what the manifest claims as ours). **Neither ever touches a file the
  manifest does not claim** — so a hand-written `settings.ini` silently keeps
  winning, by design, with a yellow line saying so. Do not re-implement any of
  this as a `.dcol` template: nothing in it is palette-derived, and a template
  cannot ask the manifest whether a file is ours.
- **All four `themes/*/theme.conf` carry identical values**, because the repo
  declares exactly one dark GTK theme (`Adwaita-dark`, a GTK3 built-in). That
  is a packaging limit, not a design one, and it is why the identity test ships
  a sandbox-only fixture theme — against shipped data alone, a regression that
  re-hardcoded `themes/dark` would stay green forever.
- **Every `colors.dcol` is generated, never hand-written.** `colorgen.sh` over
  a four-block seed image; each file's header records its seed hex and all
  three new ones were verified to regenerate byte-identical. Hand-written hex
  is how you get a palette missing a key some template references.
- **dwm and sxhkd both `XGrabKey`.** A key bound in both silently dies. The two
  keysets are disjoint on purpose; keep them that way.
- **A green `make` can compile the *old* config.** `config.h` is generated once
  and gitignored — `rm -f config.h` before rebuilding, then check the binary.
- **`~/.config/zsh` points at the main worktree**, not at whatever slot you are
  in. Shell-config changes made in a slot are not what your shell is reading.
- **The TPM plugin path is derived in two files and they must agree.**
  `TPM_DIR` in `scripts/install-restore.sh` pre-clones it;
  `config/tmux/conf.d/30-plugins.conf` tells tmux and TPM where to look. Let
  them drift and nothing errors — the installer clones where tmux never looks,
  TPM's own bootstrap fetches a second copy, and you get two plugin trees.
  `tests/tmux-tpm-lockstep.sh` guards it.
- **`tmux.conf` is not a shell.** It expands `$VAR` and `${VAR}` but has no
  `${VAR:-default}`, so an unset variable silently collapses the path around
  it. Every path in `30-plugins.conf` therefore lives inside a
  **single-quoted** `run-shell` body, which tmux passes through untouched for
  `/bin/sh` to expand. Double quotes let tmux expand first and put the bug
  straight back. This is also why the bootstrap is one `run-shell` doing its
  own `-d` check rather than `if-shell` wrapping a `run-shell`: the nested
  form needs an inner quoting level, and there isn't a safe one.

---

## What is genuinely unproven

Be precise about this rather than optimistic.

- **The installer has never run on a Fedora box.** Every package name is
  checked by hand against packages.fedoraproject.org (`CLAUDE.md` rule 8); none
  has ever been resolved by a live `dnf`. There is no `dnf` on the dev host —
  **it is Arch**.
- **The dev host is Wayland**, so nothing that composites, grabs keys, or locks
  the screen has been exercised against a real dwm/X11 session.
- Verification to date is: `shellcheck`/`bash -n`, sandboxed `$HOME` runs with
  all four XDG vars overridden, fake binaries shimmed onto a sealed `PATH`, and
  mutation testing of the test suite itself. That is a decent floor. It is not
  the same as having booted the thing.
- CI does validate every package name against real Fedora repos
  (`install-dry-run`, 102 names across 4 lists) — that is the one live check.

---

## Testing conventions worth inheriting

- **Assume your first draft has a bug, and assume your *test* has one too.**
  Multiple green suites here were later shown to be decorative. Every test
  added in the last several tasks was mutation-tested before being trusted.
- **A test that supplies a default never tests that default.** Learned
  2026-08-12: `tests/theme-identity.sh` set the two new config globals itself,
  while the real installer sets neither and relies entirely on the shipped
  `${VAR:-default}` values. Flipping a default so that every installer re-run
  would clobber the user's config left the whole suite green — the only
  survivor of 8 mutations. Mirror the real caller's calling convention,
  **including what it does not set**, and assert the defaults explicitly.
- **When a change adds siblings to a file family, the stale one is the
  original.** The three new `theme.conf` files described the new behaviour
  correctly, which is exactly what made the pre-existing `themes/dark` one —
  still describing the old behaviour — look reviewed. A four-sweep audit with
  an explicit doc pass missed it; the independent reviewer caught it as its
  single finding.
- **A grep hit is a place to look, never a conclusion.** A well-commented file
  names the tool it deliberately *avoids* at least as often as the one it
  calls. Three "missing dependencies" were found this way and all three were
  the comment explaining why the tool was not needed.
- **Never run desktop scripts to "check they work".** They drive the live
  session — `pkill dunst`, `xrdb -merge`, `feh`, `slock`. Shim the binary onto
  an isolated `PATH` and assert on the call log. Leaving `/usr/bin` on the end
  of that `PATH` defeats the whole exercise.
- `tests/*.sh` is the suite; run all 13 with
  `for t in tests/*.sh; do bash "$t"; done`. Five of them are *consistency*
  tests — two places state the same fact and the test holds them together
  (`picom-lockstep`, `autostart-daemons`, `desktop-consequences`, `pkglist`,
  `tmux-tpm-lockstep`). That shape has caught more real bugs here than any
  assertion about output.
- **CI runs every one of them** as of 2026-08-10, and runs the *scripts*
  rather than copies of their contents: `lint` calls `tests/lint.sh --strict`,
  `build-suckless` calls `tests/build.sh`. Before that those two were
  reimplemented inline and so were never executed by anything.

---

## Package tiers (new as of 2026-08-08)

`packages/*.lst`, four tiers, each with a different failure mode. Full rules in
`CLAUDE.md` rule 10.

| List | Read by | On failure |
| ---- | ------- | ---------- |
| `core.lst` | `install-pkg.sh` | aborts the run |
| `build.lst` | `install-suckless.sh` **only** | aborts the build stage |
| `desktop.lst` | `install-pkg.sh` | never aborts; red closing summary naming what broke |
| `extra.lst` | `install-pkg.sh` | never aborts; one yellow line |

Counts are deliberately not written here — they went stale within two tasks
last time. Count them:
`for f in packages/*.lst; do printf '%-22s %s\n' "$f" "$(grep -vcE '^\s*#|^\s*$' "$f")"; done`

Two things that are easy to get wrong:

- **The trailing `#` comment on a `desktop.lst` line is data, not prose.** It is
  that package's consequence text, parsed by `load_consequences()` to build the
  failure summary. `tests/desktop-consequences.sh` fails the build without it.
- **Never name the lists in a consumer.** `tests/pkglist.sh` and `ci.yml` both
  glob `packages/*.lst`, so a fifth tier is covered automatically.

`core.lst` is deliberately tiny. Growing it is tempting and wrong: a hard-fail
on a hand-checked package name converts a degraded install into no install.

---

## Settled, and worth not re-litigating

**Keybound applications belong in `desktop.lst`.** `thunar` and `firefox` were
briefly in `extra.lst` on an infrastructure-vs-application line. That line was
never written down, and it contradicted the criterion that *is* written at the
top of `desktop.lst` — *does its absence stay quiet?* Both back a key that does
nothing and says nothing when the package is missing, so both moved
(2026-08-08). The tier test is the failure mode, not the kind of program.

The queue is in `MASTER_PLAN.md`, roughly in priority order. The largest
remaining item by far is still booting the installer on real hardware.

---

## How work gets done here

Every task runs through a phase workflow in its own `git worktree` at
`.claude/worktrees/<slug>/` on branch `slot/<slug>`:

```text
/explore → /plan → /code → audit-loop → reviewer → /test → /commit → merge
```

`/commit` writes a dated log under `.claude/changes/` and resets slot state;
merging to `main` is a manual step, followed by folding the log into
`CURRENT_AUDIT.md` and updating `MASTER_PLAN.md`. Those two files are
**main-side only** — writing them from inside a slot causes conflicts.

Hard limits enforced by review: **250 lines per file, 60 per function.** Both
have forced real splits (`install-pkg.sh` → `install-pkg-tiers.sh`;
`install-session.sh` → `install-session-report.sh`; and a 294-line
`tests/theme-templates.sh` that no longer exists — it became
`tests/starship-template.sh` + `tests/fastfetch-template.sh`). Split rather
than seek an exception; the repo has no precedent for one.

One wrinkle worth knowing if you split a *sourced* file again:
`install-session.sh` resolves its sibling from `BASH_SOURCE` rather than from
the caller's `$SCRIPT_DIR`, unlike `install-restore.sh`. It has to —
`tests/autostart-daemons.sh` sources it with no `SCRIPT_DIR` set at all.
