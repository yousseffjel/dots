# network-status-block
Date: 2026-10-05
Files: 6 | Lines: about +250/-6 (two new files)

## What changed
- `suckless/dwmblocks/scripts/dwm-net` (new): `NET <ssid> <signal>%` for
  Wi-Fi, `NET eth` for wired, `NET off` otherwise. Reads
  `nmcli -t -f TYPE,STATE,CONNECTION device status` (any `connected*`
  state; `\:` unescaped; SSID cut at 16), then the signal with
  `nmcli -t -f ACTIVE,SIGNAL device wifi list --rescan no`. Every nmcli call
  is under `timeout 3`. Without nmcli output it falls back to
  `/sys/class/net/*/operstate` (lo skipped; `DWM_NET_SYSFS` overrides the
  path for the test). Left-click: `alacritty -e nmtui`, else `st`.
- `suckless/dwmblocks/blocks.def.h`: row between VOL and BT, interval 30,
  signal 11, plus a comment on why 11 sits out of order.
- `tests/dwm-net.sh` (new): fake nmcli and sysfs; 11 checks.
- `KEYBINDINGS.md` (block table now 11 rows; rebuild note), `CLAUDE.md`
  (block count), `CHANGELOG.md`.

## Why
Item 4 of the post-VM follow-ups, network row, ⭐ option chosen by the user
(a block, not the nm-applet tray icon). The roster Epic had dropped a network
block as optional ("one script plus one blocks.def.h row").

## Key Technical Decisions
- Reviewer WARN fixed before commit: the first draft required the exact state
  `connected`, so a link NetworkManager reports as "connected (externally)"
  read `off`. Now any `connected*` device state counts; loopback is
  excluded by type.

## Assumptions
- Type B: Wi-Fi wins over wired when both are up; the first listed Wi-Fi
  device (NetworkManager's order) wins over a second.
- Type B: 30 s interval, matching BT. `--rescan no` keeps it cheap.
- Known limit: `cut -c` counts bytes, so a non-ASCII SSID longer than 16
  bytes may be cut mid-character.

## Test coverage
- `tests/dwm-net.sh` passes. Mutations, on copies that include
  `suckless/`, caught 9/9. A first run of the harness was invalid (it
  never copied `suckless/`, so every "CAUGHT" was a missing file); that was
  fixed and re-run before any result was trusted.
- `tests/build.sh` builds all five programs; the fresh `dwmblocks` binary
  contains `dwm-net`.
- `tests/run-tests.sh`: 31/31. Lint passed. Reviewer: WARN (fixed, above).

## Follow-ups
- Existing installs (the VM): `rm -f suckless/dwmblocks/blocks.h`, then
  `scripts/install-suckless.sh --skip-deps`, then restart dwmblocks
  (log out and in).
