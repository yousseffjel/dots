# screen-recorder
Date: 2026-10-05
Files: 7 | Lines: about +380/-4 (two new files)

## What changed
- `config/dwm/bin/dwm-record` (new): one key toggles. Not recording:
  `record>` full | region (dmenu; `--full`/`--region` skip it), then
  `ffmpeg -f x11grab -framerate 30 [-video_size WxH] -i $DISPLAY[+x,y]`
  with `libvpx-vp9 -deadline realtime -cpu-used 8 -row-mt 1 -crf 32 -b:v 0
  -pix_fmt yuv420p` into `~/Videos/recordings/dots-recording-*.webm`,
  backgrounded, `</dev/null`, log in `$XDG_RUNTIME_DIR/dwm-record/`.
  Full screen size comes from xrandr's "current" and region geometry from
  slop; both rounded down to even (yuv420p). Recording: SIGINT (ffmpeg's
  clean stop), wait up to 5 s, then TERM; "Recording saved <path>". The pid
  is trusted only if `/proc/<pid>/comm` is `ffmpeg`. An ffmpeg that dies
  within 0.5 s is reported with the log path.
- `config/sxhkd/sxhkdrc`: `super + r` → `dwm-record`.
- `packages/desktop.lst`: `ffmpeg-free`, with the RPM Fusion conflict noted
  in its comment and consequence text.
- `KEYBINDINGS.md` (`### Screen recording`), `CHANGELOG.md`, `CLAUDE.md`.
- `tests/dwm-record.sh` (new): Python fake ffmpeg (see Key decisions).

## Why
Item 4 of the post-VM follow-ups, screen recorder row, ⭐ option chosen by
the user (ffmpeg + slop + dmenu, not obs-studio, which is Qt).

## Key Technical Decisions
- `input_args` fills a global array instead of printing: the first draft ran
  it inside `<( )`, where `fail`'s `exit` would only end the subshell and
  `set -e` could kill the subshell before its status line was printed.
- The test's fake ffmpeg is Python. A job a non-interactive bash script
  starts with `&` inherits SIGINT as ignored, and bash cannot trap a signal
  ignored on entry. Real ffmpeg resets the handler: verified on this host,
  where a backgrounded ffmpeg showed SigIgn 0x1000 (SIGPIPE only) and stopped
  0.4 s after SIGINT with a finalised file.
- After the reviewer's READY the suite caught the test exiting 1 despite its
  green line: `set -e` applies inside the EXIT trap, and a `pkill` that
  matched nothing aborted the cleanup (also skipping the `rm -rf`). The
  cleanup is now a function with every step unfailing. Test file only.

## Assumptions
- Type B: video only; no bar indicator while recording (a notification says
  how to stop instead).
- Rule 8: `ffmpeg-free` verified on mdapi (f43 7.1.5, f44 8.1.3); the
  Fedora `ffmpeg` spec has `--enable-libxcb` and `--enable-libvpx`.

## Test coverage
- End to end with real ffmpeg on Xvfb (1281x721): start, 2 s, stop. The
  result was VP9 1280x720, 2.57 s, state cleared, both notifications sent.
- `tests/dwm-record.sh`: 24 checks. Mutations caught 6/6: TERM instead of
  INT, no comm check (the stray process got killed), no even rounding, no
  liveness check, stop keeping state, region offset dropped.
- `tests/run-tests.sh`: 34/34. Lint passed. Reviewer: READY.

## Follow-ups
- On the VM: try Super+r once; x11grab on the virtio GPU is untested.
