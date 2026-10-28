# dots

**dots** turns a fresh Void Linux install into a complete, themed dwm desktop
with one command. It builds a suckless-based X11 desktop (dwm, st, dmenu,
dwmblocks, slock, all vendored and patched in the repo), adds the ly login
screen, PipeWire, NetworkManager and a set of everyday applications, and links
a zsh + tmux shell setup. The colours follow your wallpaper.

- **Target:** Void Linux, glibc, x86_64, runit. Nothing else is supported.
- **Hardware:** desktops, laptops and virtual machines. It has run end to end
  in virtual machines; bare metal is still unproven.
- **Source:** [github.com/YoussefFjel/dots](https://github.com/YoussefFjel/dots)

## Using dots

| Page | What it covers |
| ---- | -------------- |
| [Installation](Installation) | From the Void live ISO, or onto a Void base install you already have |
| [First Steps](First-Steps) | The first login, the bar, the first keys to learn |
| [Keybindings](Keybindings) | The keys you will use every day |
| [Theming](Theming) | Wallpapers, the four static themes, the login screen |
| [Using the Desktop](Using-the-Desktop) | Screenshots, recording, clipboard, notifications, files, sounds |
| [Laptops and Hardware](Laptops-and-Hardware) | Drivers, NVIDIA, backlight, battery, touchpad, VMs |
| [The dots Command](The-dots-Command) | `dots theme`, `dots doctor`, `dots update` and the rest |
| [Updating and Uninstalling](Updating-and-Uninstalling) | Staying current, and taking it all back out |
| [Troubleshooting](Troubleshooting) | `dots doctor` and the problems people actually hit |

## Working on dots

| Page | What it covers |
| ---- | -------------- |
| [Architecture](Architecture) | The repo layout, the installer stages and the install manifest |
| [Contributing](Contributing) | The workflow and the rules every change follows |
| [Packages](Packages) | The package tiers and how names are checked |
| [Suckless and Patches](Suckless-and-Patches) | The vendored programs and how patches are recorded |
| [Testing and CI](Testing-and-CI) | The test suite, the linters and the CI jobs |
| [Theming Engine](Theming-Engine) | Wallpaper to palette to templates to live reload |
| [Session and Autostart](Session-and-Autostart) | `.xinitrc`, `autostart.sh` and the session daemons |

## About this wiki

The pages live in the repo's
[`wiki/`](https://github.com/YoussefFjel/dots/tree/main/wiki) directory and are
published here by
[`scripts/wiki-publish.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/wiki-publish.sh).
An edit made on GitHub is overwritten by the next publish, so open a pull
request against `wiki/` instead.
