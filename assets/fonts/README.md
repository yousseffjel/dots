# Vendored font: Cascadia Code NF

`CascadiaCodeNF-2407.24.tar.xz` holds the two **variable** Nerd Font faces
from Microsoft's Cascadia Code release, and nothing else. The restore stage
(`scripts/install-restore-font.sh`) extracts it into
`~/.local/share/fonts/`. It runs no `fc-cache`: fontconfig rescans a new
user font directory by itself, and a cache written at install time would
outlive `dots uninstall` (that script's header has the details). Every config that
needs Nerd Font glyphs names the family it registers, `Cascadia Code NF`:
`config/fontconfig/fonts.conf`, alacritty, the suckless `config.def.h` files
and nsxiv's X resources. `tests/fontconfig-stack.sh` holds those names
against this asset.

## Why vendored

Void does not package Cascadia Code in any variant (checked against the repo
index, 2026-10-15). Fedora's `cascadia-code-nf-fonts` used to supply it.
Scope I decision D3 (`.claude/tasks/scope-i-void-port.md`) chose vendoring
over switching to a packaged Nerd Font, so the terminal and bar look the
same as before. It follows the `assets/cursors/` pattern: a pinned artifact,
its checksum, and its license next to it, with no network at install time.

## Provenance

This tarball is **repacked**, not an upstream artifact. The upstream release
is one 150 MB zip with every format and weight, far too large to commit. The
two files inside are byte-identical to the zip's.

| | |
| --- | --- |
| Upstream | [microsoft/cascadia-code](https://github.com/microsoft/cascadia-code) |
| Release | `v2407.24` (published 2024-11-27) |
| Source asset | `CascadiaCode-2407.24.zip`, SHA-256 `e67a68ee3386db63f48b9054bd196ea752bc6a4ebb4df35adce6733da50c8474` |
| `ttf/CascadiaCodeNF.ttf` | SHA-256 `16d00fae9fc289cda8c9ee4c578ccb4d410f3fa54ec0e5a3901c059b0248a970` |
| `ttf/CascadiaCodeNFItalic.ttf` | SHA-256 `95fb04b5aaae44c4cb698cfd1b62bddc44e899845f3c494c342d2b0bbf19572e` |
| This tarball | SHA-256 in `CascadiaCodeNF-2407.24.tar.xz.sha256` |
| License | **SIL OFL 1.1**: `LICENSE.CascadiaCode`, from the repo at the same tag (the zip carries none) |

The variable fonts carry every weight as a named instance (Regular, Bold,
Light, SemiBold, ... and the Italic set), so the 24 static files are not
needed. The OFL allows redistribution of unmodified font software; the
Reserved Font Name applies only to modified versions, and these are
unmodified.

## Rebuilding or updating

Nothing watches upstream for a new release, the same as `assets/cursors/`.
The repack is reproducible: the commands below rebuild exactly the committed
SHA-256 from the files above.

```sh
curl -fsSLO https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip
unzip -q CascadiaCode-2407.24.zip 'ttf/CascadiaCodeNF.ttf' 'ttf/CascadiaCodeNFItalic.ttf' -d x
mkdir -p stage/CascadiaCodeNF && cp x/ttf/CascadiaCodeNF*.ttf stage/CascadiaCodeNF/
tar --sort=name --mtime='2024-11-19 00:00Z' --owner=0 --group=0 --numeric-owner \
    --mode=u+rw,go+r,go-w -cf - -C stage CascadiaCodeNF | xz -9e -T1 >CascadiaCodeNF-2407.24.tar.xz
sha256sum CascadiaCodeNF-2407.24.tar.xz >CascadiaCodeNF-2407.24.tar.xz.sha256
```

For a new release, change the tag and both file names, and update the table
above. Keep exactly **one** tarball in this directory: the installer refuses
to guess between two.
