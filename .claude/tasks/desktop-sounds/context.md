# Context — desktop-sounds

## Background
Scope K (.claude/tasks/scope-k-integrated-desktop.md) slot 4; user chose pw-play + sound-theme-freedesktop.

## Prior Decisions
- Rule 6 autostart three places; dunstrc/dunst.dcol lockstep (tests/dunst-reload.sh).

## References
- Void pipewire-1.6.9_1: ./usr/bin/pw-play, run_depends libsndfile (plays .oga)
- Void sound-theme-freedesktop-0.8_3: stereo/{service-login,message-new-instant,dialog-warning,audio-volume-change,screen-capture}.oga

## Notes
- dunst 1.13.2 probe (private bus + Xvfb, scratchpad dunstprobe): script runs when a notification is
  DISPLAYED; paused notifications run it on unpause; critical runs while paused; always_run_script=true
  re-ran a notification already showing when the pause lifted (duplicate) — false does not.
  Bare `script = name` is found on PATH; `~` expands. DUNST_CATEGORY / DUNST_STACK_TAG are exported.
- CORRECTION (second probe, the SHIPPED dunstrc): pause level 100 (set-paused true, what dwm-notify uses)
  holds CRITICAL notifications too — the first probe's default config differed. Focus mode is fully silent.
