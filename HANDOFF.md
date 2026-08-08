# Handoff

Written 2026-08-08, at commit `13b6902`. For whoever picks this repo up next —
including a future session of me.

This is deliberately **not** a summary of the other docs. It is the set of
things that are true, load-bearing, and not obvious from reading the code.

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
| `.claude/changes/YYYY-MM-DD-*.md` | 37 dated logs, one per task | Full detail incl. assumptions and follow-ups |
| `ROADMAP.md` | Comparison vs. HyDE (Arch/Hyprland) | **Partly stale by design** — an idea backlog, not current state |
| `TESTING.md` | How to run the 8 test scripts | Current |
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
3. **`polkit-gnome`** — **still open.** Packaged in `extra.lst`, autostarted by
   nothing, so no polkit agent runs and GUI privilege prompts fail silently.
   Queued in `MASTER_PLAN.md`.

The structural defence is in place now: `scripts/install-session.sh` states the
daemon set twice (the `autostart.sh` heredoc for fresh machines,
`session_autostart_report()` for existing ones), and
`tests/autostart-daemons.sh` fails if the two disagree. **Adding a daemon to
only one of them is the mistake that test exists to catch.**

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
- **dwm and sxhkd both `XGrabKey`.** A key bound in both silently dies. The two
  keysets are disjoint on purpose; keep them that way.
- **A green `make` can compile the *old* config.** `config.h` is generated once
  and gitignored — `rm -f config.h` before rebuilding, then check the binary.
- **`~/.config/zsh` points at the main worktree**, not at whatever slot you are
  in. Shell-config changes made in a slot are not what your shell is reading.

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
- **A grep hit is a place to look, never a conclusion.** A well-commented file
  names the tool it deliberately *avoids* at least as often as the one it
  calls. Three "missing dependencies" were found this way and all three were
  the comment explaining why the tool was not needed.
- **Never run desktop scripts to "check they work".** They drive the live
  session — `pkill dunst`, `xrdb -merge`, `feh`, `slock`. Shim the binary onto
  an isolated `PATH` and assert on the call log. Leaving `/usr/bin` on the end
  of that `PATH` defeats the whole exercise.
- `tests/*.sh` is the suite; run all 8 with
  `for t in tests/*.sh; do bash "$t"; done`. Four of them are *consistency*
  tests — two places state the same fact and the test holds them together
  (`picom-lockstep`, `autostart-daemons`, `desktop-consequences`, `pkglist`).
  That shape has caught more real bugs here than any assertion about output.

---

## Package tiers (new as of 2026-08-08)

`packages/*.lst`, four tiers, each with a different failure mode. Full rules in
`CLAUDE.md` rule 10.

| List | Read by | On failure |
| ---- | ------- | ---------- |
| `core.lst` (2) | `install-pkg.sh` | aborts the run |
| `build.lst` (13) | `install-suckless.sh` **only** | aborts the build stage |
| `desktop.lst` (26) | `install-pkg.sh` | never aborts; red closing summary naming what broke |
| `extra.lst` (61) | `install-pkg.sh` | never aborts; one yellow line |

Two things that are easy to get wrong:

- **The trailing `#` comment on a `desktop.lst` line is data, not prose.** It is
  that package's consequence text, parsed by `load_consequences()` to build the
  failure summary. `tests/desktop-consequences.sh` fails the build without it.
- **Never name the lists in a consumer.** `tests/pkglist.sh` and `ci.yml` both
  glob `packages/*.lst`, so a fifth tier is covered automatically.

`core.lst` is deliberately tiny. Growing it is tempting and wrong: a hard-fail
on a hand-checked package name converts a degraded install into no install.

---

## Open decisions

Neither blocks anything; both are cheap now and annoying later.

1. **`polkit-gnome` autostart** — the third instance of the bug shape above.
2. **Do keybound *applications* belong in `desktop.lst`?** `thunar` and
   `firefox` are in `extra.lst` on an infrastructure-vs-application line. Both
   are still named in the failure summary; the tier only decides whether they
   are flagged as a broken desktop. One-line move either way.

The rest of the queue is in `MASTER_PLAN.md`, roughly in priority order.

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
have forced real splits (`install-pkg.sh` → `install-pkg-tiers.sh`, and a
294-line `tests/theme-templates.sh` that no longer exists — it became
`tests/starship-template.sh` + `tests/fastfetch-template.sh`). Split rather
than seek an exception; the repo has no precedent for one.
