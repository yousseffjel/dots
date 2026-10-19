# Context — release-0.5.0

## Background
MASTER_PLAN Queue "Release 0.5.0" (user 2026-10-19). Corrected 2026-10-19: no header refresh needed.

## References
- Vendored nsxiv Makefile uninstall (from archive/nsxiv-package/context.md): $PREFIX/bin/nsxiv, $PREFIX/share/man/man1/nsxiv.1, $PREFIX/share/applications/nsxiv.desktop, $PREFIX/share/icons/hicolor/{16x16,32x32,48x48,64x64,128x128}/apps/nsxiv.png, rm -rf $PREFIX/share/doc/nsxiv/examples.
- install-suckless.sh (0.4.0) wrote SUCKLESS<TAB>nsxiv<TAB>/usr/local/bin/nsxiv.
- CONTRIBUTING.md "Cut a release"; tests/migration-current.sh runs the real step in env -i with no rows.
- uninstall_steps.sh skips a SUCKLESS row whose suckless/<prog> has no Makefile.
