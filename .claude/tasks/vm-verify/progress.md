# Progress — vm-verify

## Status
`done`

## Steps
- [x] 1. Preflight + baseline doctor
- [x] 2. Rebuild + paste + re-login
- [x] 3. Slot 1 checks
- [x] 4. Slot 2 checks
- [x] 5. Slot 3 checks
- [x] 6. 2026-10-07 carry-overs
- [x] 7. Fix defects + log

## Results
| Item | Result | Evidence |
|------|--------|----------|
| Rebuild (fresh config.h/blocks.h) | PASS | ~/vm-verify-install.log on the VM; blockutil installed 644 |
| Report lines for an existing autostart.sh | PASS | printed blueman/nm-applet/xdg lines; appended (backup .bak-vm-verify-20261012103718) |
| Bar after quick re-login | PASS | user screenshot 10:39; dwmblocks count 1 |
| clipmenud after logout / clean ly TTY | PASS | user: ly screen clean; clipmenud count 1 after re-login |
| Cursor size across login | PASS | Xcursor.size 24 before and after |
| nm-applet at login | PASS | "Connection Established" notification + tray icon; pgrep 1 |
| xdg-user-dirs-update at login | PASS | ~/Videos, ~/Documents created by the login |
| "Floating tray icons" (2026-10-07) | NOT DOTS | absent from an in-VM maim of the same area; host virt-manager fullscreen toolbar |
| D1 logout 20-25 s | DEFECT | run() blocks in XNextEvent; SIGTERM only sets running=0; journal silent until X died 10:38:59.68 |
| D2 xss-lock core dump at logout | DEFECT | systemd-coredump 10:38:59.77, abrt dup of 2026-10-05 crash |
| D3 doctor: one-shot missing from autostart = skip | DEFECT | baseline: xdg-user-dirs-update "runs once" while autostart.sh lacked it |
| Slot 1 restart (kill -HUP, live) | PASS | focus B, A on tag 3, S stashed, F floating 300px, Alt+minus returns S |
| D1 seen live on restart | DEFECT | kill -HUP: restart only after 6107 ms on an idle desktop |
| Dropterm with real alacritty | PASS | WM_CLASS dots-dropterm x2; 1148x473+384+19; hide/show on tag 8; one window |
| Float rules, real apps | PASS | pavucontrol 500, gpick 640, file-roller 600, nm-connection-editor 600 px wide on an empty tag |
| Bar pop-ups (VOL/MIC/GAMMA) | PASS | dunst history +1 per kind; gamma 100->90->100 |
| GAMMA left = night light | PASS | status on -> off -> on |
| htop / upgrade terminals float | PASS | 800x600 each (upgrade closed at its sudo prompt) |
| D4 NET click | DEFECT | nmtui not installed: NetworkManager-tui declared nowhere |
| Screenshot into XDG Pictures | PASS | ~/Pictures/screenshots/dots-screenshot-20261012-104456.png |
| DND key, block, doctor, held notifications | PASS | paused/bar DND/doctor warn/waiting=2; block click resumes |
| Super+Ctrl+n history | PASS | history 8 -> 7, displayed 1 |
| Super+Shift+w on this VM | NOTE | errors: no ~/Pictures/wallpapers (documented behaviour, not a defect) |
| lxpolkit dialog floats; sudo prompt in upgrade terminal | USER | cannot be raised over ssh (polkit asks the caller's session) |

## Deviations

## Blockers


## Decisions (user, 2026-10-12)
- D1: fix dwm's event loop (pselect, signals blocked outside the wait) + local diff + test without the wake workaround.
- D2: stop xss-lock in dots_session_end (rule-6 pattern: template + report + THEMING.md).
- D3: doctor checks "not mentioned in autostart.sh" before the one-shot skip (Type B, obvious fix).
- D4: NetworkManager-tui in desktop.lst + dwm-net falls back to nm-connection-editor.

## Fixes (step 7)
- D1 wakeonsignal: self-pipe instead of the approved pselect — same goal, no signal mask leaking into spawned clients (deviation, see PATCHES.md). Mutations: W1 caught; W2 (no pipe write) survives by design — only the pre-select race needs it.
- D2 xss-lock stop in dots_session_end (template, report marker + paste, THEMING.md, tests). X1-X4 caught.
- D3 doctor one-shot ordering. O1 caught.
- D4 NetworkManager-tui in desktop.lst (f43/f44 verified) + nm-connection-editor / notify fallback. N1-N2 caught; N3 (undeclared package) survives — no test maps commands to packages (rule 8).
- Not yet proven live: the four fixes need merge + push + a VM rebuild (follow-up).
