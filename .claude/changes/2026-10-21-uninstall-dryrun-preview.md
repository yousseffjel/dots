# uninstall-dryrun-preview
Date: 2026-10-21
Files: 6 (+ task folder) | Lines: +231/-8 (incl. task folder)

## What changed
- `scripts/global_fn.sh` `confirm()`: under `DRY_RUN=1` it answers yes without reading, printing `(dry-run) <prompt> — previewing`.
- `scripts/uninstall_steps.sh` `uninstall_state`: the trailing `[[ -n "$keep_path" ]] && echo …` is an `if`.
- `scripts/uninstall.sh` header: "dnf packages" → "xbps packages".
- `docs/UNINSTALL.md`: the "one category at a time" paragraph says a dry run asks nothing and previews every category.
- New `tests/uninstall-dry-run.sh`.
- CHANGELOG `[Unreleased]`: two lines.

## Why
Void VM edge-case loop (2026-10-20): `uninstall.sh --dry-run </dev/null` exited 0, but every category printed "skipped …". Each category's y/N prompt came before its DRY_RUN branch, so a dry run with no terminal, or answered N, previewed nothing, though the docs promise "preview every action". uninstall_state already skipped its prompt in a dry run; every other category now does the same, through confirm().
Reading uninstall_state turned up a second bug of the same class as migrate-dryrun-current. Answering y to "remove the state dir" and N to "keep a copy of the log" left `[[ -n "" ]] && echo` as the function's last command. It returned 1, and set -e ended uninstall.sh just before "✓ uninstall complete". `--yes` always keeps the copy, so tests/install-uninstall-symmetry.sh could not see it.

## Assumptions
- Type B: a dry run answering every prompt "yes" is safe. That holds only if every confirm-guarded block checks DRY_RUN itself. The reviewer verified it for every call site, root ones included. The sandbox test proves it for the HOME-side categories (snapshot identical, sudo/xbps/usermod/pkill sentinels silent). The per-section tests cover the root-side ones.
- Type C: confirm() is in global_fn.sh, but no caller outside scripts/uninstall*.sh uses it.

## Test coverage
- New test: 3 failures before the fix (no preview, every category skipped, uninstall_state returns 1). All pass after.
- Mutants on a scratch copy, 5/5 caught, each by its intended check:
  - confirm asks again;
  - uninstall_apps ignores DRY_RUN;
  - the configs step ignores DRY_RUN;
  - the flatpak step ignores DRY_RUN;
  - uninstall_state's one-liner restored.
  A first M4 survived because it was malformed (its trailing `if false; …; fi` returned 0); it was redone as the exact original line.
- Full suite rc=0 (99 OK); lint passed; reviewer READY.
- **Not run on the VM.** It was shut off on 2026-10-21, and after a restart the ssh agent socket was gone (key needs a passphrase).

## Follow-ups
- VM: overlay these files onto a main snapshot and run `uninstall.sh --dry-run </dev/null`. Expect every category previewed, and the manifest, HOME and /etc untouched. Never a real uninstall without the user's yes.
- Remove the VM's `/etc/sudoers.d/zz-claude-vm-test` when testing ends.
