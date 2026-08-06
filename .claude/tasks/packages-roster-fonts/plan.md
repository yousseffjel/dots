# Plan — packages-roster-fonts

## Goal
Sub-task 2 of the roster Epic: settle `packages/*.lst` as the final roster and
adopt the user's real `starship.toml` over the placeholder sub-task 1 shipped.
Every added name is verified against packages.fedoraproject.org — this dev host
is Arch, so there is no `dnf` to ask (CLAUDE.md rule 8).

## Scope
- `packages/*.lst`
- `config/starship/**`
- `scripts/install-pkg.sh`

## Allowed
- packages
- config/starship
- scripts/install-pkg.sh
- .claude/tasks/packages-roster-fonts

## Forbidden
- config/zsh
- suckless

## Steps
1. Verify each candidate on packages.fedoraproject.org: alacritty, starship, zoxide,
   fastfetch, firefox, maim, slop, xss-lock, unar, thunar-volman, ffmpegthumbnailer,
   catfish, bluez, blueman + both Nerd Fonts. Record the method.
2. Add verified names to `extra.lst` under the existing category comments; drop
   `kitty`. Anything unverifiable gets a header note, not a guess (rules 4 and 8).
3. Adopt `~/.config/starship/starship.toml`, replacing the ASCII placeholder.
4. Swap the `󰣇` Arch logo for a Fedora one — wrong distro for this target.
5. Measure prompt render time as-adopted vs `right_format` trimmed; report both
   numbers, let the user pick the cut. Do not trim unilaterally.
6. Verify: `tests/pkglist.sh`, `tests/lint.sh`, starship parses and renders.

## Out of scope
- Installing anything; starship `.dcol` theming (sub-task 9); `eza --icons`.

## Risks
- Names look plausible but are wrong — `tests/pkglist.sh` checks syntax, never existence.
- Fedora splits Nerd Fonts per-family under non-obvious names; verify, don't translate.
- Adopting 405 lines wholesale can import breakage — step 6 renders it.
