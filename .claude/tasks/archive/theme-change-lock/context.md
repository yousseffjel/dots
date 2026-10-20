# Context — theme-change-lock

## Background
Void VM, 2026-10-20: two concurrent `dots wallpaper --random`. .fehbg =
game-relaxed-mario.png (run 2, set 17:14:25.13); colors.dcol pry1 #0C2244 from
nature-dunes-sunset.jpg (run 1, written 17:14:27.22). Desktop: mario wallpaper,
dunes palette.

## Prior Decisions
- reload.sh holds its lock on an explicit fd, closed in the dwmblocks spawn,
  because `exec flock ... "$0"` leaked the fd into the detached daemon.

## References
- util-linux flock 2.41.4 (VM) / 2.42.4 (host): a command run by `flock FILE CMD`
  inherits the lock fd (checked: /proc/$$/fd lists it); `-o` closes it.

## Notes
- No nesting: wallpaper.sh and theme-apply.sh never call each other.
