# Context — idle-dim

## Background
Scope K slot 5, assumption A2 (scope-k-integrated-desktop.md).

## Probes (2026-10-27, Void host)
- xss-lock(1): the notifier runs when the saver activates from idle, and is killed on
  activity or when the locker starts. The locker starts at the first cycle (xset s TIMEOUT CYCLE).
- xserver source (XQuartz/xorg-server mirror; gitlab.freedesktop.org blocks fetches):
  dix/window.c dixSaveScreens SCREEN_SAVER_ON. With prefer-blanking it calls
  pScreen->SaveScreen, which is xf86SaveScreen (hw/xfree86/modes/xf86Crtc.c:3069),
  i.e. xf86DPMSSet(DPMSModeOff): today the monitor goes OFF at 600 s, not at 660.
  noblank + noexpose gives SCREEN_ISNT_SAVED, which draws nothing.
  ScreenSaverHandle (Xext/saver.c) sends the Notify before that switch, so xss-lock
  still sees ON, and a second timeout becomes CYCLE (os/WaitFor.c + the type logic).
- xrandr under Xvfb (-noreset; without it every client disconnect resets the server):
  `--gamma 1.0:0.8:0.6 --brightness 0.9` reads back `Gamma: 1.0:1.3:1.7`
  (INVERTED, one decimal). `--brightness 0.5` alone reads back Gamma 1.0:1.0:1.0,
  so it drops the tint. gammastep -O 4000 -b 0.8 reads back Gamma 1.0:1.3:1.6, Brightness 0.80.
