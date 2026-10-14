# Plan — vm-picom

## Goal
(1) drivers_chassis also answers `vm` (systemd-detect-virt --vm; wins over a
chassis type or a battery a hypervisor exposes; desktop behaviour). (2)
picom's backend choice moves out of the user-owned autostart.sh into
config/dwm/bin/dwm-picom (linked, so every install gets future fixes):
VM -> xrender always; real hardware -> glx only on a hardware 3D renderer;
xrender otherwise. Doctor compares the running backend with dwm-picom's
choice and names the reason. Existing autostart.sh files are told the one
line to paste.

## Scope
- scripts/{drivers-detect,drivers-laptop,doctor-session,install-session-template,install-session-report}.sh
- config/dwm/bin/dwm-picom
- tests/{picom-backend-probe,drivers,doctor}.sh, tests/lib/{drivers-cases,doctor-sandbox}.sh
- docs/{HARDWARE,THEMING}.md, CHANGELOG.md, CLAUDE.md

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. drivers_is_vm + `vm` in drivers_chassis/_why (DOTS_VIRT override honoured).
2. config/dwm/bin/dwm-picom: `backend` prints "<backend><TAB><reason>"; `start` (default) execs picom unless running.
3. Template compositor block -> `dwm-picom &`; report tells an old autostart.sh to switch (with or without the inline probe).
4. Doctor: running backend vs dwm-picom backend -> ok with reason / warn on mismatch (e.g. glx in a VM).
5. Tests: dwm-picom matrix (VM+virgl, VM+llvmpipe, real GPU, no glxinfo...), template + report, chassis vm cases, doctor.
6. Docs: CLAUDE.md rule 6 picom sentence, THEMING.md, HARDWARE.md, CHANGELOG.
7. VM: dwm-picom backend -> xrender "virtual machine (kvm)"; doctor row.

## Out of scope
- picom.conf tuning; Workstation as a target

## Risks
- autostart.sh is user-owned: only NEW installs get `dwm-picom &` — report covers the rest
- glxinfo in doctor costs up to 5 s (timeout) — only inside a dwm session
