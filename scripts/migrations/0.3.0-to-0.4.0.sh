#!/usr/bin/env bash
# 0.3.0 -> 0.4.0: nothing to migrate — this script exists so migrate.sh can
# take the step (it stops at a step with no script, leaving the manifest at
# 0.3.0 and `dots doctor` warning; see CONTRIBUTING.md, "Cut a release").
#
# Run once by scripts/migrate.sh before the install stage. migrate.sh records
# the new version itself on success — this script never touches the manifest.
#
# WHY NOTHING. What 0.4.0 changes reaches an existing install on its own:
#   * dwm-picom lives in config/dwm/bin, which every install links, so it is
#     there the moment the repo is pulled. The autostart.sh line that runs
#     it is the user's to add — that file is user-owned (CLAUDE.md rule 6),
#     and the installer's report says exactly what to paste. Until then the
#     inline probe an older autostart.sh carries keeps choosing a backend.
#   * the `vm` chassis result, the installer's honest status lines, the
#     clipmenu COPR step and the Fedora Server note are all read live by
#     the scripts that the installer run after this one executes.
#   * no manifest row format changed.
set -euo pipefail

green() { printf '\033[32m%s\033[0m\n' "$*"; }

green "0.3.0 -> 0.4.0: no migration step needed (the installer run that follows brings everything in)"
