#!/usr/bin/env bash
# 0.2.0 -> 0.3.0: nothing to migrate — this script exists so migrate.sh can
# take the step.
#
# Run once by scripts/migrate.sh (install-void.sh calls it before the install
# stage). migrate.sh records the new version itself on success — this script
# never touches the manifest. Without a <from>-to-<to> script it stops, the
# manifest stays at 0.2.0, and `dots doctor` warns on every 0.2.0 install that
# its version does not match the repo.
#
# WHY NOTHING. Everything 0.3.0 adds is picked up by the installer run that
# follows:
#   * dots drivers and the laptop support run inside the package stage;
#   * the changed suckless headers (dwmblocks' blocks.def.h gained the BAT
#     block) need no help: since 0.2.0, install-suckless.sh itself refreshes
#     a generated header that is unedited but older than its *.def.h, which
#     was the whole job of 0.1.0-to-0.2.0.sh;
#   * new manifest categories (SYSFILE) are only ever written, never read
#     back from an older install.
#
# KNOWN AND NOT FIXABLE HERE: before 0.3.0 the package stage could record a
# preinstalled Thunar as `PACKAGE thunar` (it asked rpm for the name, and
# Fedora's package is `Thunar`, which provides `thunar`). Whether dots
# installed Thunar cannot be told after the fact, so the row is left alone;
# CHANGELOG [0.3.0] tells the user how to check.
set -euo pipefail

green() { printf '\033[32m%s\033[0m\n' "$*"; }

green "0.2.0 -> 0.3.0: no migration step needed (the installer run that follows brings everything in)"
