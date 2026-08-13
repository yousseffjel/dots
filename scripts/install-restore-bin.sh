#!/usr/bin/env bash
# Sourced by install-restore.sh. Installs the single user-facing command,
# `dots`, as a symlink in ~/.local/bin.
#
# Deliberately NOT handled by symlinks.sh: that script links whole directories
# out of config/ into ~/.config (rule 7). This is one file out of scripts/ into
# a different root, and it needs a not-ours guard of its own.
#
# Exactly ONE name is claimed. ~/.local/bin precedes ~/.config/dwm/bin in
# config/zsh/.zshenv, so anything dropped here shadows the dwm-* controls;
# "dots" collides with nothing in either directory, which is the whole reason
# this is a dispatcher rather than four symlinked entry points.
#
# Expects the caller to have set DRY_RUN, SCRIPT_DIR, and the red/green/yellow/
# blue helpers, and to have sourced global_fn.sh for manifest_append_row.

# Resolved at call time, not source time, so a test can point HOME elsewhere
# between sourcing this file and running the function.
restore_dots_bin() {
    local src="$SCRIPT_DIR/dots"
    local dst="$HOME/.local/bin/dots"

    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        blue "  (dry-run) would link dots -> $dst"
        return 0
    fi

    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        # Re-run: already ours. Re-assert the manifest row rather than skipping.
        # The link outlives a reset manifest, and the append is idempotent.
        manifest_append_row SCRIPT dots "$dst"
        green "ok      dots already linked -> $dst"
        return 0
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        # Someone else's file, or a link into a different checkout, under our
        # name. Never clobber it and never claim it: a SCRIPT row is precisely
        # what authorises uninstall.sh to delete a path, so registering a file
        # we did not create is the one unrecoverable mistake available here.
        # See manifest_has_path's header in global_fn.sh.
        yellow "warn    $dst exists and is not ours — left untouched"
        yellow "        run the repo copy directly instead: $src"
        return 0
    fi

    # Guarded, not bare: the caller runs under `set -e`, so an unguarded ln
    # failure (unwritable ~/.local/bin, read-only $HOME) would abort the whole
    # restore stage — every later step skipped — over a convenience symlink.
    # The repo's convention for a deploy that can fail is to degrade loudly and
    # carry on, which is what install-restore-cursor.sh's tar already does.
    if mkdir -p "$(dirname "$dst")" && ln -s "$src" "$dst"; then
        manifest_append_row SCRIPT dots "$dst"
        green "linked  dots -> $dst"
    else
        red "could not link $dst — the dots command will not be on \$PATH"
        yellow "        run the repo copy directly instead: $src"
    fi
}
