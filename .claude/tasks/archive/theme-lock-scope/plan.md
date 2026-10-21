# Plan — theme-lock-scope

## Goal
theme-lock.sh takes the change lock before arguments are parsed, so commands
that change nothing wait behind a change and fail with 75: `dots theme
--list` (the Super+Shift+t menu builds its list from it), --help,
--login-random. Worse, `wallpaper.sh --select` holds the lock for as long as
its dmenu picker stays open, so Super+w and the theme menu fail meanwhile.
Lock only the change itself.

## Scope
- scripts/theme/theme-lock.sh
- scripts/theme/wallpaper.sh
- scripts/theme/wallpaper-login-random.sh
- tests/theme-lock.sh
- CHANGELOG.md
- CLAUDE.md

## Allowed

## Forbidden

## Steps
1. Split: login_random + login_random_hint -> wallpaper-login-random.sh
   (sourced; wallpaper.sh is at the 250-line cap).
2. tests/theme-lock.sh: with the lock held, --list/--help/--login-random
   run at once; real wallpaper.sh --select: fake dmenu sees the lock FREE,
   stub colorgen sees it HELD, wall.set written.
3. theme-lock.sh: no lock for -h/--help/--list/--login-random/--select.
4. wallpaper.sh --select: exec itself with the chosen path (locked run).
5. CHANGELOG line; CLAUDE.md map names the new file.

## Out of scope
- doctor creating flatpak/dconf stores on a fresh HOME (first-use side effect of
  the tools themselves; noted in the log).

## Risks
- --select re-exec loses the original args — it only needs the path.
