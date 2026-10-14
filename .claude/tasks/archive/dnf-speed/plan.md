# dnf-speed — Medium

Goal: a fresh install should not crawl behind one slow mirror and ~130 dnf runs.
User decisions (2026-10-14): persistent drop-in; batch per tier + per-package fallback.

## Steps
1. `config/dnf/30-dots-speed.conf` (NEW): fastestmirror=True, max_parallel_downloads=10,
   minrate=20k, timeout=30. Values verified on the F44 VM via --dump-main-config.
2. `scripts/sysfile-lib.sh` (NEW): `sysfile_install kind rel dst what after fail` —
   drivers_touchpad's SYSFILE contract lifted out verbatim (edited/unclaimed kept,
   unedited old copy replaced, row on write). drivers_touchpad becomes a caller.
3. `scripts/install-pkg-dnf.sh` (NEW, sourced by install-pkg.sh): `dnf_speed_conf`
   (drop-in into /etc/dnf/libdnf5.conf.d, DOTS_DNF_CONF_DIR for tests) and
   `dnf_refresh` (one `dnf makecache` up front, best-effort, visible).
4. `install-pkg-tiers.sh`: install_tier collects what is missing, ONE
   `dnf install -y --skip-unavailable` (stderr shown live, indented, and kept);
   then per package rpm -q decides installed/failed; dnf's own line per failed
   name. Transaction failure (rc≠0) → per-package fallback (old path).
5. `install-pkg.sh`: drop the C Development group step (fails on every F44 run —
   dead; build.lst is the declared toolchain, rule 10). Call 3 before tiers.
6. uninstall-sysfiles.sh confirm text; tests: pkg-tiers (batch, fallback,
   skip-unavailable), new dnf-speed-conf test, drivers touchpad unchanged green.
7. Docs: CLAUDE.md map, docs/UNINSTALL.md if it lists SYSFILE, CHANGELOG.

## Out of scope
- Doctor check for the drop-in. Per-package timeout wrapper (minrate covers it).
