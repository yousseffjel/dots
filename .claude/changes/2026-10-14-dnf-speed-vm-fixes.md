# dnf-speed VM fixes — two flaws found by the first real run

## What changed
- `scripts/install-pkg-tiers.sh`: the batch `dnf install` runs with
  `</dev/null`.
- `scripts/install-pkg-dnf.sh`: `dnf_refresh` runs `dnf makecache -q --refresh`.
- tests/pkg-tiers.sh: fake dnf records a stdin that is not /dev/null; tier()
  feeds a regular file as stdin so a runner's own /dev/null cannot hide it.
  tests/dnf-speed-conf.sh asserts --refresh.

## Why
Run of 906e5e0 on the F44 Server VM (192.168.122.182), 16:32 local:
everything worked (drop-in written and read by dnf — `dnf5
--dump-main-config` shows fastestmirror=1, max_parallel_downloads=10,
minrate=20480; SYSFILE row; gpick+catfish in one transaction; doctor all
passed after reboot), with two flaws:
1. The streamed dnf progress "staircased": each line began where the last
   ended. The tee'd log was clean ($-terminated lines), and a no-sudo
   reproduction over `ssh -tt` kept onlcr set, so the terminal mode changed
   only under sudo — sudo's use_pty puts the user's terminal in raw mode
   while relaying stdin.
2. "Total ... 00m52s" for 975 KiB: dnf5.log showed the fastestmirror probe
   (`lr_fastestmirror_sort_internalmirrorlists: Duration: 49.718331`) inside
   the install; the downloads took <1 s. `dnf makecache` had found the
   metadata fresh and contacted no mirror, so the labelled probe step was a
   no-op.

## Key Technical Decisions
- Keep fastestmirror on: cold probe 50 s (packages) / ~7 s (metadata-only,
  measured as the user with the cache moved aside), then cached; it chose a
  48 ms mirror. --refresh costs ~5 s per installer run.

## Assumptions Made
- (B) sudo with use_pty leaves the terminal alone when stdin is not a tty —
  inferred, not verified with sudo on the VM (needs the user's password).
  The next VM run confirms or refutes it.

## Test coverage
- Mutations: dropping `</dev/null` and dropping `--refresh` are each caught.
- Suite 72/72, lint ✓.

## Follow-ups
- Re-run on the VM after a `dnf remove` of two leaf packages and confirm the
  progress lines no longer staircase.
