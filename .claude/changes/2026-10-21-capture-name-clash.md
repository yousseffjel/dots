# capture-name-clash
Date: 2026-10-21
Files: 7 | Lines: +99/-8

## What changed
- `dwm-screenshot` and `dwm-record` each gained `reserve <path>`: creates
  the first free one of path, path-2, path-3 … with noclobber (`set -C`,
  atomic) and prints it, giving up after RESERVE_TRIES (99) with a
  reported failure.
- dwm-screenshot `deliver` moves the shot onto the reserved name;
  dwm-record runs `ffmpeg -y` onto it, and removes the empty reservation
  when ffmpeg dies at once or writes nothing.
- tests/dwm-screenshot.sh and tests/dwm-record.sh: a fake `date` pinned to
  one second; two captures must keep two files; no empty file left behind.
- CHANGELOG [Unreleased] Fixed.

## Why
Found during the monitor-capture VM check: two screenshots in the same
second got the same seconds-resolution name and the second `mv` replaced
the first. dwm-record's restart within a second handed ffmpeg an existing
file, which it refuses without -y (stdin /dev/null, it cannot ask).

## Assumptions
- Type B: a `-N` suffix rather than a finer NAME_FMT — names stay as
  documented and sortable. Alternative: milliseconds in the name.

## Test coverage
- Tests failed first; 6/6 mutants caught (noclobber removed ×2, no
  reserve, constant suffix, no -y, empty reservation kept).
- Audit Medium+ tier (7 files incl. state), four sweeps, 0 open.
- Full suite 104 OK; lint passed; reviewer READY.
- VM: three concurrent `--full --file` shots → `…-311.png`, `-2`, `-3`;
  two real recordings under a clock pinned to one second → `.webm` and
  `-2.webm`, both valid VP9.

## Follow-ups
- none
