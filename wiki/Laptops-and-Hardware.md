# Laptops and Hardware

dots runs on desktops, laptops and virtual machines. It works out which one it is on, installs what the hardware
needs, and turns on laptop behaviour only on a laptop.
[docs/HARDWARE.md](https://github.com/YoussefFjel/dots/blob/main/docs/HARDWARE.md) is the full reference.

**A caveat first:** no laptop has been available to test on. Laptop behaviour is covered by tests against recorded
fixtures and by the VM, not by a real laptop. Nothing has been run on bare metal yet. See
[Installation](Installation#what-is-not-proven).

## `dots drivers`

```sh
dots drivers --dry-run   # what it would install, changing nothing
dots drivers
```

The installer runs this for you, so a fresh install is already covered. Run it yourself after swapping a GPU or
moving the install to other hardware. It installs:

- **The video decoding driver for your GPU** (VA-API), so mpv decodes H.264 and HEVC on the GPU rather than the CPU:
  `intel-media-driver` or `libva-intel-driver` for Intel, `mesa-vaapi` for AMD, `nvidia-vaapi-driver` for NVIDIA once
  the NVIDIA driver is loaded.
- **The Vulkan driver for your GPU**, so mpv renders through Vulkan: `mesa-vulkan-radeon` for AMD, `mesa-vulkan-intel`
  for Intel from Broadwell (2014) on.
- **Missing firmware.** It reads the kernel log for firmware files a driver failed to load, and installs the
  `linux-firmware-*` package that ships each one. Reboot afterwards.
- **CPU microcode** on bare metal: `intel-ucode` (from Void's nonfree repository) or `linux-firmware-amd`, then it
  rebuilds the initramfs. It takes effect at the next boot.
- **fwupd** on bare metal, for firmware updates. It is never run for you; apply updates yourself with
  `fwupdmgr refresh && fwupdmgr update`. `dots doctor` warns when updates are pending.
- **The laptop packages**, on a laptop only.

Everything it installs is recorded, so `dots uninstall` removes it again. It never adds a repository itself.

## NVIDIA: reported, never installed

The NVIDIA driver is a kernel module rebuilt for every new kernel. If that build fails, the machine boots with no
graphical session. So `dots drivers` identifies the card and prints the command for the right driver branch, and
does not run it:

```text
NVIDIA GPU 0000:01:00.0: GP104 [GeForce GTX 1080] (kernel driver: nouveau)
  sudo xbps-install -S void-repo-nonfree && sudo xbps-install -S nvidia580
```

Run it yourself if you want it, then run `dots drivers` again to add video decoding.

## Laptop, desktop or VM

`dots drivers` and `dots doctor` both say which one this machine is, and why:

```text
laptop (chassis type 10, battery BAT0) — packages/laptop.lst:
```

- **vm** is checked first, from the kernel's `hypervisor` CPU flag and the DMI vendor. A VM is treated as a desktop,
  whatever chassis or battery the hypervisor pretends to have.
- **laptop** means the firmware reports a portable chassis type, **or** the machine has a system battery. A wireless
  mouse's or headset's battery does not count.
- **desktop** means a desktop chassis type. Anything else is **unknown**, and is treated as a desktop: nothing
  laptop-only is installed on a guess.

## What changes on a laptop

A desktop behaves exactly as before. On a laptop:

- **The brightness keys dim the backlight** through `brightnessctl`, and the bar's brightness block shows a lamp
  (`󰛨`). On a desktop the same keys dim the picture with xrandr gamma, which saves no power, and the block shows a
  sun (`󰃟`). Backlight control works through the `video` group, which the installer adds you to.
- **The bar shows the battery.** It turns the warning colour at 15% and the urgent colour at 5%, with one
  notification at each. Left-click for the time left or to full. A desktop's bar has no battery block.
- **The touchpad taps to click**: one finger left, two right, three middle, with natural scrolling and palm
  rejection while typing. The settings are in `/etc/X11/xorg.conf.d/40-dots-touchpad.conf`. Log out and back in
  once after it is first written. Edit that file to change a setting; dots never overwrites an edited copy.
- **Power profiles.** `Super` + `Shift` + `p`, or *profile* in the power menu, switches between power-saver,
  balanced and performance. The choice survives a reboot. It needs no password at the machine, and is refused over
  ssh.

dots does not suspend or hibernate at a critical battery level itself. That remains elogind's job, and your choice.

## Virtual machines

A VM gets no microcode or firmware (they belong to the host) and no video driver. It does get:

- **picom's `xrender` backend, never `glx`.** On a GPU without 3D acceleration, which includes most VMs, the glx
  backend froze the screen right after login. `dwm-picom` chooses the backend at every login: `xrender` in any VM,
  `glx` only on bare metal with real hardware 3D. `dwm-picom backend` prints the choice and why, and `dots doctor`
  warns when the running picom disagrees. Editing `backend` in `picom.conf` has no effect.
- **The SPICE guest agent**, so the screen follows the viewer's window size when the viewer supports it.

Two settings belong to the VM, not to dots:

- **Screen size.** A fresh VM starts at 1024x768. Pick a mode with `Super` + `Shift` + `d`, then *save this layout
  as a profile*, and it is re-applied at every login.
- **A blurry login screen.** ly draws on the kernel console, which keeps the boot mode. Add a `video=` mode such as
  `video=Virtual-1:1920x1080` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` (the output name is in
  `ls /sys/class/drm`), run `sudo update-grub`, and reboot.

`dots doctor` warns about spice-vdagent in a VM displayed over VNC rather than SPICE. That warning is expected there.
