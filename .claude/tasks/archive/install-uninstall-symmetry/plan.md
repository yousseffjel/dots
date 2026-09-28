# Plan — install-uninstall-symmetry

## Goal
scope-d slot D. Prove restore -> uninstall returns a sandboxed $HOME to its
pre-install state, per the manifest. Fix the one real asymmetry found
(mimeinfo.cache, unclaimed and re-created by uninstall's own refresh). The
.zshenv ZDOTDIR line and zinit/TPM clones stay as DOCUMENTED leftovers
(docs/UNINSTALL.md "What's kept, always" — user chose to honor it 2026-09-28).

## Scope
- scripts/install-restore-apps.sh
- scripts/uninstall-apps.sh
- tests/install-uninstall-symmetry.sh
- tests/lib/install-symmetry.sh
- docs/UNINSTALL.md, TESTING.md, CHANGELOG.md, CLAUDE.md
- scripts/install-restore-theme.sh, scripts/uninstall-theme.sh, scripts/uninstall_steps.sh, scripts/uninstall.sh
- .claude/**

## Allowed
## Forbidden
- suckless/
- config/

## Steps
1. install-restore-apps.sh: claim mimeinfo.cache as an APP row only when this run created it
2. uninstall-apps.sh: skip the desktop-db refresh when no .desktop remains and the cache is gone
3. tests/lib/install-symmetry.sh: fakes (git clone, update-desktop-database, sentinel sudo/dnf/systemctl/chsh/pkill/xrdb), snapshot, sandbox env
4. tests/install-uninstall-symmetry.sh: fresh + lived-in scenarios, restore x2, uninstall --yes, compare files/symlinks; documented leftovers must be in UNINSTALL.md
5. Mutations: drop an APP claim; drop the cache claim; break backup restore
6. Docs: UNINSTALL.md (cache + the test), TESTING.md, CHANGELOG

## Out of scope
- Removing the .zshenv line / clones (user decision: honor)
- Packages/services/suckless/shell rows (need root; install-container covers them)

## Risks
- Real manifest pollution — all four XDG vars + env -i; assert no /tmp rows in the real manifest after
- Desktop side effects — sentinel fakes for pkill/xrdb/systemctl, asserted never called
