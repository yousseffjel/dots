# Context — laptop-battery

## Background
scope-h slot 3 (`.claude/tasks/scope-h-laptop-support.md`). Slots 1+2 merged as `916bf0e`.

## Prior Decisions
- scope-h: laptop behaviour only where a battery exists; desktop unchanged.
- scope-h slot 3 note: prefer the block timer over a new daemon (rule 6 otherwise).
- dwmblocks appends the delimiter only after blocks that printed text (dwmblocks.c:114), so an empty block costs no space.

## References
- suckless/dwmblocks/scripts/dwm-dnd (empty-unless pattern), dwm-temp (WARN/URGENT colours)
- tests/lib/blocks.sh harness (env -i, sealed PATH, notify-send fake)
- power_supply ABI: capacity, status (Charging/Discharging/Full/Not charging), energy_now/energy_full (uWh), charge_now/charge_full (uAh), power_now/current_now, scope

## Notes
- Signals 1-12 used; 13 is free.
