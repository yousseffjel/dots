# vulkan-drivers
Date: 2026-10-28
Files: 6 (drivers-gpu.sh, its test + cases, docs/HARDWARE.md, the wiki's hardware page, this log)

## What changed
- `scripts/drivers-gpu.sh`: `dots drivers` installs the GPU's Vulkan driver
  next to its VA-API one: `mesa-vulkan-radeon` (RADV) on AMD,
  `mesa-vulkan-intel` (ANV) on Broadwell+ Intel. Pre-Broadwell Intel gets
  none (ANV starts at Broadwell). Same `pkg_ensure` contract, best-effort.
- `tests/lib/drivers-cases.sh`: asserts both, and that pre-Broadwell gets no
  ANV. `tests/drivers.sh` header updated.
- `docs/HARDWARE.md` table + paragraph, `wiki/Laptops-and-Hardware.md` list.

## Why
User asked to check that the system uses its hardware fully. Audit on the
user's laptop (Ryzen 5 PRO 215 / Radeon 740M, HawkPoint2, amdgpu):
- Xorg: modesetting + glamor on radeonsi, DRI2/DRI3 — fully accelerated.
- VA-API: radeonsi_drv_video loads; an h264_vaapi encode through ffmpeg6
  succeeded.
- CPU: amd-pstate-epp active, EPP balance_performance, ppd "balanced";
  microcode loaded (linux-firmware-amd).
- Vulkan: NO radeon ICD — only virtio_icd*.json in /usr/share/vulkan/icd.d.
  vulkan-loader is installed (mpv depends on it), so mpv's gpu-next tried
  Vulkan and fell back to OpenGL. That is the gap fixed here.
- picom v13: `picom --diagnostics` parses ~/.config/picom/picom.conf with no
  warning. Checked against the v12/v13 release notes (github.com/yshui/picom
  /releases): none of the removed options (glx-swap-method, sw-opti, ...) or
  deprecated ones (glx-no-stencil, glx-no-rebind-pixmap, resize-damage) is
  used. The legacy per-window options (fade-exclude, inactive-dim, wintypes,
  mark-ovredir-focused) are superseded by `rules` but still honoured while
  `rules` is unset. Left unchanged.

## Assumptions Made
- Type B: Vulkan rides on `dots drivers` (per GPU), not desktop.lst, since
  the right ICD depends on the GPU.
- Type B: `dots doctor` still checks only the VA-API driver; a Vulkan check
  was not added.
- Not touched: `amdgpu.dcdebugmask=0x410` in the user's /etc/default/grub
  (set by hand, not by dots; disables PSR/Replay — a Phoenix/HawkPoint
  flicker workaround that costs some battery).

## Verified
- `tests/drivers.sh`, `tests/void-pkgnames.sh`, `tests/lint.sh`,
  `tests/wiki-links.sh` pass.
- Not yet run for real on the laptop: `dots drivers` needs the user's sudo
  password.
