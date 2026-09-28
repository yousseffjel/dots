# Context — dwm-bin-tests

## Background
MASTER_PLAN Recently Closed 2026-08-12: "Seven dwm-* scripts remain untested; dwm-brightness is the highest-value next". User chose "All seven" 2026-09-28.

## Prior Decisions
- tests/dwm-colorpicker.sh and dwm-display.sh set the pattern (fakes on PATH, --list where possible).

## References
- memory: dots-testing-via-fake-binary-on-path, shims-must-match-real-output-format

## Notes
- Real `xrandr --verbose` checked 2026-09-28 (read-only): unindented output headers, TAB-indented `Brightness: 0.45`.
- Drafted in scratch first; all four green there (19+14+16+17 assertions).
