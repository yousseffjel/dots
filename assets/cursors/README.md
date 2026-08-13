# Vendored cursor theme

`Bibata-Modern-Classic.tar.xz` is an upstream release artifact, committed to
this repo unmodified. `scripts/install-restore-theme.sh` extracts it into
`~/.local/share/icons/` at install time; `themes/*/theme.conf` then names it as
`cursor_theme`.

## Provenance

| | |
| --- | --- |
| Upstream | [ful1e5/Bibata_Cursor](https://github.com/ful1e5/Bibata_Cursor) |
| Release | `v2.0.7` |
| Asset | `Bibata-Modern-Classic.tar.xz` |
| Size | 1,767,748 bytes |
| SHA-256 | recorded in `Bibata-Modern-Classic.tar.xz.sha256` |
| License | **GPL-3.0** — full text in `LICENSE.Bibata` |

The tarball contains one top-level directory, `Bibata-Modern-Classic/`, holding
`index.theme`, `cursor.theme` and `cursors/`. That single directory path is
what the installer records in the manifest, so `uninstall.sh` removes the whole
tree (`uninstall_theme` uses `rm -rf`, not `rm -f`).

The upstream `LICENSE` is vendored alongside the artifact because the release
tarball does **not** carry one. This follows the same convention as
`suckless/*/LICENSE`: vendored upstream material keeps its upstream license
next to it.

## Why vendored rather than packaged or downloaded

Fedora does not package Bibata; it is COPR-only, and CLAUDE.md rule 4 makes
enabling a COPR an explicit user decision rather than an installer default.
Downloading at install time was rejected too — it puts a network dependency and
a supply-chain trust decision inside the install path, and release URLs rot.

Vendoring is what the reference implementation does:
`HyDE/Scripts/restore_fnt.sh` extracts from `${cloneDir}/Source/arcs/*.tar.gz`
and never fetches anything. Note the extension difference — Bibata's Linux
assets are `.tar.xz`, so extraction uses `tar -xJf`, not HyDE's `-xzf`.

## Updating

Nothing watches this file. There is no Renovate rule, no Dependabot stanza, and
no CI job that checks upstream for a newer release — the same blind spot the 23
vendored `suckless/*/patches/*.diff` files have. Bumping it is manual:

```sh
cd assets/cursors
curl -sSLO https://github.com/ful1e5/Bibata_Cursor/releases/download/<tag>/Bibata-Modern-Classic.tar.xz
sha256sum Bibata-Modern-Classic.tar.xz > Bibata-Modern-Classic.tar.xz.sha256
curl -sSL -o LICENSE.Bibata https://raw.githubusercontent.com/ful1e5/Bibata_Cursor/<tag>/LICENSE
```

Then update the Release / Size rows in the table above and run
`tests/cursor-theme.sh`, which verifies the archive against the recorded
checksum and asserts the top-level directory name still matches what
`themes/*/theme.conf` declares as `cursor_theme`.

## Changing the variant

`cursor_theme` in all four `themes/*/theme.conf` must match the tarball's
top-level directory name. Swapping to a different Bibata variant
(`Bibata-Modern-Ice`, `Bibata-Original-Classic`, …) means replacing the
artifact, its `.sha256`, and that name in all four theme files together —
`tests/cursor-theme.sh` fails the build if they disagree.
