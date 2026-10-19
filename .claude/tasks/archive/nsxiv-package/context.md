# Context — nsxiv-package

## Background
MASTER_PLAN "what still undone" item 5 (user 2026-10-19: "4 + 5 + 6"). scope-i-void-port.md:95 left "nsxiv 34 and xcolor" as an open, low-priority question ("Ask before changing either"). AskUserQuestion answers: nsxiv = "Void's package (Recommended)", xcolor = "Keep the script (Recommended)".

## Prior Decisions
- 2026-10-13 (default-apps): nsxiv vendored because Fedora did not package it, at the user's choice over sxiv/imv. CLAUDE.md rule 4 records it as the one built-program vendoring exception.
- Rule 8: a package name is verified against Void's index, and its meaning by reading the .xbps file list.

## References (verified 2026-10-19)
- repo-default.voidlinux.org/current/nsxiv-34_1.x86_64.xbps contents: /usr/bin/nsxiv, man1/nsxiv.1, /usr/share/applications/nsxiv.desktop (byte-identical to suckless/nsxiv/etc/nsxiv.desktop), hicolor icons 16-128, doc/nsxiv/examples. run_depends: imlib2, libX11, libXft, libexif, fontconfig.
- void-packages srcpkgs/nsxiv/template: build_style=gnu-makefile, install-all, no files/config.h, so it builds upstream config.def.h. Its one patch (no-rebuild-options.patch) is Makefile plumbing.
- tests/fixtures/void-x86_64-pkgs.tsv:8675 `nsxiv main`.
- Vendored Makefile install paths (needed by the release migration): $PREFIX=/usr/local: bin/nsxiv, share/man/man1/nsxiv.1, share/applications/nsxiv.desktop, share/icons/hicolor/{16x16,32x32,48x48,64x64,128x128}/apps/nsxiv.png, share/doc/nsxiv/examples/.

## Notes
- PATCHES.md: version.h comes from `git describe` of the dots repo, so the v0.5.0 tag would have made `nsxiv -v` print the dots tag. One more reason to switch before the release.
- dwm-colorpicker's header already says the script stays although Void packages xcolor.
