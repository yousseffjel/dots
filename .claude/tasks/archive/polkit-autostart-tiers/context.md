# Context — polkit-autostart-tiers

## Background

Queue items 1 and 2 in `MASTER_PLAN.md`, both raised by `package-tiers`
(2026-08-08) and both selected by the user in one instruction.

1. **`polkit-gnome` is packaged but nothing autostarts it** — the third
   instance of the shape `HANDOFF.md` now documents (picom, sxhkd, this).
2. **Do keybound applications belong in `desktop.lst`?** `thunar` and
   `firefox` were left in `extra.lst` on an infrastructure-vs-application
   line. Asked twice during `package-tiers`, unanswered both times.

## Prior Decisions

- **`desktop.lst`'s written criterion** (its own header): *"without this
  package a shipped keybind, an autostart daemon, or the theming engine
  silently does nothing."* By that text `thunar` and `firefox` qualify — they
  are `super + e` and `super + b`. The infrastructure-vs-application filter
  that kept them out was an extra rule applied on top, never written down.
  This task resolves in favour of the written criterion.
- **CLAUDE.md rule 6** — `autostart.sh` is user-owned once it exists. The
  installer only ever prints the missing line; every existing install
  (including the user's) must paste it by hand.
- **CLAUDE.md rule 10** — the trailing `#` on a `desktop.lst` line is that
  package's consequence text, read by `load_consequences()`.
  `tests/desktop-consequences.sh` enforces one per entry, min 20 chars.
- **`tests/autostart-daemons.sh`** pairs the `autostart.sh` heredoc against
  `session_autostart_report()`. Adding a daemon to only one side fails it —
  that is the whole point of the test.

## References

- `scripts/install-session.sh` — `session_autostart_report()` (line 22),
  `session_autostart_template()` (line ~103)
- `config/sxhkd/sxhkdrc:98` `super + b` -> firefox, `:101` `super + e` -> thunar
- `tests/autostart-daemons.sh:61` `DAEMONS=(...)`, `:76` the backgrounded-command
  extractor `grep -oE '^[[:space:]]*[^#[:space:]][^&]*&[[:space:]]*$'`
- `.claude/changes/2026-08-08-package-tiers.md`, `2026-08-08-picom-autostart.md`

## Notes

**Verified this session (2026-08-08), not assumed:**

- **`polkit-gnome` is current in Fedora 43, 44 and Rawhide**, not EPEL-only.
  The first `packages.fedoraproject.org` page listed only EPEL 9, which looked
  like a retired package; the search page contradicted it. Worth re-checking
  before trusting either page alone.
- **The agent binary is NOT on `$PATH`.** On this Arch host it is
  `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`. Fedora commonly
  uses `/usr/libexec/`. **Three fetches failed to produce Fedora's actual file
  list**, so the path stays unverified — hence probing both explicitly rather
  than hardcoding a guess. Copying the `command -v picom` pattern would produce
  a line that silently never fires, which is the very bug being fixed.
- **Nothing in this repo processes XDG autostart** — no `dex`, no
  `fbautostart`, no `xdg-autostart`, and `grep -rn polkit scripts/ config/`
  returns nothing. So whatever `.desktop` file the package ships under
  `/etc/xdg/autostart/` is inert on a dwm session. That is *why* it never runs,
  and why a per-daemon line in `autostart.sh` is the right fix rather than
  adding a whole autostart runner.

**Test-compatibility trap for step 3 (verify before step 4).** The extractor
only sees lines ending in `&`, and matches the daemon name against that line's
text. A loop over a `$path` variable would background `"$p" &` — no "polkit"
in it — so the test would report the daemon as launched by nothing. Two
explicit `if`/`elif` branches, each naming the full literal path, keep the
name in the backgrounded line and stay greppable. Confirm this before relying
on it.

**Sizing.** Medium — 8 files across scripts, packages, tests and docs. No new
file, no new subsystem; the machinery all exists and this is its first real
exercise since being built.
