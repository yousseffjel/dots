# void-i3-xbps-engine — I-3: the package engine moves from dnf to xbps

## What changed
- `scripts/install-pkg-tiers.sh` rewritten for xbps:
  - `pkg_installed` / `pkg_available` / `pkg_index_synced`;
  - names not in the index are failed before the transaction;
  - one `xbps-install -y` batch per tier, with per-package retry if it fails;
  - `tier_fail` split out; SATISFIED_BY removed.
- `scripts/install-pkg-xbps.sh` (new): `xbps_prepare` runs `-Syu xbps`, then
  `-yu`, on every run. Neither step is fatal.
- Deleted: `scripts/install-pkg-dnf.sh`, `config/dnf/` and
  `tests/dnf-speed-conf.sh`. `install-pkg.sh` no longer runs the starship
  upstream script or creates the fd shim.
- `install-suckless.sh`: build deps via `xbps-install -Sy`, missing names
  only. `install-pre.sh`: checks for xbps, plus a musl note.
- `uninstall_steps.sh`: `xbps-remove -Ry` on PACKAGE rows still installed.
  `doctor-checks.sh`: per-name `xbps-query`, gated on os-release `ID=void`.
  `version.sh`: `os_version` replaces `fedora_version`. The `dwm-lock` hint
  now names xbps.
- Tests:
  - `pkg-tiers.sh` rewritten; `uninstall-packages.sh` (new);
  - `install-pre.sh`, the doctor sandbox and the symmetry sentinels updated;
  - `pkg-repos.sh` sources the tiers as the installer does.
- Docs: CLAUDE.md map, UNINSTALL.md, sysfile comments, CHANGELOG, scope
  (I-3 outcome).

## Key Technical Decisions
- **User decision:** a full system upgrade on every run, because Void has no
  partial upgrades. Chosen over upgrading only on the first install, and over
  warning only.
- Filter with `xbps-query -R` before the batch: one unknown name aborts a
  real xbps transaction (probed).
- Filter to installed names before `xbps-remove`, and to missing names before
  the build-dep install. Both because of probed behaviour: remove fails the
  whole call on a gone name, and install prints `ERROR:` for each installed
  name.
- A dry run with no synced index lists packages as unchecked would-installs,
  so the core tier does not abort (reviewer WARN).

## Assumptions Made
- (B) `xbps-uhelper arch` reports `x86_64-musl` on a musl install (the
  static binary did, with XBPS_ARCH set). Not seen on a real musl box.

## Test coverage
- Real xbps-static 0.60.7 probes (scratch root, live repos):
  - query exit codes: installed / not, in the index / not;
  - an unknown name in a batch: exit 2 with the "not found in repository
    pool" message;
  - reinstall: exit 0 with an ERROR line;
  - remove of a name that is gone: exit 2;
  - nothing to upgrade: exit 0;
  - `xbps-uhelper arch`.
- Mutations on a tree copy, 10/10 caught:
  - pkg-tiers: no prefilter, per-package transactions, stdin not /dev/null,
    no PACKAGE row, upgrade dropped, the unsynced fix removed (now as
    reported checks, not a test abort);
  - uninstall: no installed filter, `-R` dropped;
  - doctor blind to missing packages;
  - musl note removed.
- `tests/run-tests.sh` 76 OK, 1 SKIP. `tests/lint.sh --strict` passes.
  Reviewer: WARN (dry run on an unsynced index), fixed, then READY.

## Follow-ups
- I-4: repos (nonfree + sublime-text4; remove COPR, Sublime HQ and RPM
  Fusion). Still dnf until then: drivers (I-7), dwm-updates (I-8), CI (I-9).
