# Context — xdg-autostart

## References
- dex-0.10.1_1 (Void .xbps, python3), probed 2026-10-23: -s replaces the search list;
  skips OnlyShowIn (XDG_CURRENT_DESKTOP unset), Hidden=true, a missing TryExec;
  runs NotShowIn=KDE; IGNORES X-GNOME-Autostart-enabled=false; one non-boolean
  Hidden raises ValueError and ends the whole -a run.
- dwm.c runautostart: system("autostart.sh &") — PPID is a transient sh, not dwm;
  restart = execvp, same PID and start time.
