# void-i4-nonfree-repo — I-4: the repos step is Void's nonfree repo only

## What changed
- `scripts/install-pkg-repos.sh` rewritten:
  - installs `void-repo-nonfree`, re-syncs (`xbps-install -S`), then
    installs `sublime-text4`;
  - writes `REPO package nonfree void-repo-nonfree` only when this run
    enabled nonfree;
  - glibc x86_64 only (musl and other arches skip, with the nvim fallback
    named);
  - the COPR, Sublime HQ and RPM Fusion/ffmpeg-swap code is deleted.
- `scripts/install-pkg-tiers.sh`: new shared `pkg_ensure` (skip if
  installed, dry run, PACKAGE row, yellow failure). I-7 should point
  `drivers_pkg` at it.
- `scripts/uninstall-repos.sh`: `uninstall_repos` handles `package` rows. It
  removes nonfree only while no installed package comes from it, and fails
  closed on either query. `uninstall_repo_swaps` is unchanged; it goes in
  I-7.
- Tests: `pkg-repos.sh` rewritten (9 scenarios). `default-apps.sh` now maps
  sublime_text.desktop to sublime-text4 via `pkg_ensure`.
- Docs/comments: CLAUDE.md rule 4 + map + clipmenu note, THUNAR.md,
  UNINSTALL.md, TESTING.md, CHANGELOG, scope. Comments in mimeapps.list,
  mpv.conf, dwm-clipmenu, dwm-record, extra.lst, the autostart template,
  flatpak restore and install-void.sh. The lazygit note now gives the xbps
  command.

## Key Technical Decisions
- Nonfree is an official, Void-signed repo, but still a user-authorised
  choice under rule 4, with the same revert contract as Flathub.
- "In use" comes from one query:
  `xbps-query -i --repository=<nonfree url> -Rs ''`, where `[*]` marks an
  installed package. It is not a per-package walk.
- **lazygit not added to extra.lst.** Void has it (`lazygit-0.65.1_1`), but
  the roster is the user's decision. The closing message gives the command.

## Assumptions Made
- (B) The `[*]` marker reflects install state by name, not origin, so a
  same-named package from another repo would read as "from nonfree". Void's
  nonfree and main names do not overlap in practice.

## Test coverage
- Probed with xbps-static 0.60.7 (scratch root, live repos):
  - the nonfree conf only becomes usable after a second `-S`;
  - the `-L` format;
  - the `[*]`/`[-]` listing before and after removing unrar;
  - the sublime-text4 .xbps file list and its Exec line.
- Mutations on a tree copy, 8/8 caught: no re-sync, no REPO row, always
  re-enable, sublime attempted after a failed enable, uninstall ignoring
  use, in-use ignoring `[*]`, no arch guard, and the `-L` fail-closed check
  removed.
- `tests/run-tests.sh` 76 OK, 1 SKIP. `tests/lint.sh --strict` passes.
  Reviewer: WARN (`-L` failure failed open), fixed, then READY.

## Follow-ups
- I-5: services and login (runit, ly from source with pinned zig, elogind,
  D4 groups).
- Decide whether lazygit joins extra.lst.
