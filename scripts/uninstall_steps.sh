#!/usr/bin/env bash
# One function per scripts/uninstall.sh confirmation category — split out
# once uninstall.sh crossed the 250-line cap (file-architecture.md).
# Sourced by uninstall.sh only, never standalone: every function here
# assumes the caller has already `set -euo pipefail`, sourced
# global_fn.sh (for confirm()/manifest_rows()), overridden
# red()/green()/yellow()/blue() to also mirror into $LOG_FILE, and set
# DOTS_DIR/DRY_RUN/ASSUME_YES/SUDO/MANIFEST_DIR/MANIFEST_FILE/LOG_FILE.
#
# usage: source "$SCRIPT_DIR/uninstall_steps.sh"

uninstall_configs() {
    blue "=== configs ==="
    mapfile -t config_rows < <(manifest_rows CONFIG)
    if [[ ${#config_rows[@]} -eq 0 ]]; then
        blue "  no CONFIG rows in manifest — nothing to remove"
    elif confirm "Remove ${#config_rows[@]} deployed config symlink(s) (restoring a backup where one exists)?"; then
        for row in "${config_rows[@]}"; do
            IFS=$'\t' read -r _ src target backup <<<"$row"
            if [[ ! -L "$target" || "$(readlink "$target")" != "$src" ]]; then
                yellow "  skip    $target (not currently our symlink — left alone)"
                continue
            fi
            if [[ $DRY_RUN -eq 1 ]]; then
                if [[ "$backup" != "-" ]]; then
                    blue "  (dry-run) would remove $target and restore backup $backup"
                else
                    blue "  (dry-run) would remove $target (no backup to restore)"
                fi
                continue
            fi
            rm "$target"
            if [[ "$backup" != "-" && -e "$backup" ]]; then
                mkdir -p "$(dirname "$target")"
                mv "$backup" "$target"
                green "  restored $target (from $backup)"
            else
                green "  removed  $target"
            fi
        done
    else
        yellow "  skipped configs"
    fi
}

uninstall_suckless() {
    blue "=== suckless binaries ==="
    mapfile -t suckless_progs < <(manifest_rows SUCKLESS | cut -f2 | sort -u)
    if [[ ${#suckless_progs[@]} -eq 0 ]]; then
        blue "  no SUCKLESS rows in manifest — nothing to uninstall"
    elif confirm "Uninstall ${#suckless_progs[@]} suckless program(s) (${suckless_progs[*]})?"; then
        for prog in "${suckless_progs[@]}"; do
            dir="$DOTS_DIR/suckless/$prog"
            if [[ ! -f "$dir/Makefile" ]]; then
                yellow "  skip    $prog (no Makefile at $dir)"
                continue
            fi
            if [[ $DRY_RUN -eq 1 ]]; then
                blue "  (dry-run) would run: make -C $dir uninstall"
                continue
            fi
            if "${SUDO[@]}" make -C "$dir" uninstall >/dev/null 2>&1; then
                green "  uninstalled $prog"
            else
                red "  failed to uninstall $prog (needs root — check sudo access)"
            fi
        done
    else
        yellow "  skipped suckless binaries"
    fi
}

# Everything this installer drops into ~/.local/bin, which `make uninstall`
# in uninstall_suckless never sees:
#   * dwmblocks block scripts — deployed by `make install-scripts`, a separate
#     target from `make install` (see install-suckless.sh)
#   * the `dots` command — a symlink to scripts/dots (see install-restore.sh)
# Both carry SCRIPT rows, so both are removed here. The prompt deliberately
# does not name either one: it counts the manifest rows instead, because a
# hardcoded "dwmblocks block scripts" would have started lying the moment the
# second kind of row appeared.
uninstall_scripts() {
    blue "=== scripts in ~/.local/bin ==="
    mapfile -t script_paths < <(manifest_rows SCRIPT | cut -f3)
    if [[ ${#script_paths[@]} -eq 0 ]]; then
        blue "  no SCRIPT rows in manifest — nothing to remove"
    elif confirm "Remove ${#script_paths[@]} script(s) this installer put in ~/.local/bin?"; then
        for path in "${script_paths[@]}"; do
            if [[ $DRY_RUN -eq 1 ]]; then
                blue "  (dry-run) would remove $path"
                continue
            fi
            if rm -f "$path"; then
                green "  removed  $path"
            else
                red "  failed to remove $path"
            fi
        done
    else
        yellow "  skipped ~/.local/bin scripts"
    fi
}

# Theme files are COPIES, not symlinks (config/dunst and config/picom are
# deliberately not symlinked — the theming engine rewrites those targets on
# every wallpaper change, and a symlink would make it write into the repo).
# So they cannot go through uninstall_configs, which verifies readlink and
# skips anything that is not our own symlink. Generated cache files under
# ~/.cache/dots are removed too: they are wholly derived, nothing there is
# user data.
uninstall_theme() {
    blue "=== theme files ==="
    mapfile -t theme_paths < <(manifest_rows THEME | cut -f3)
    if [[ ${#theme_paths[@]} -eq 0 ]]; then
        blue "  no THEME rows in manifest — nothing to remove"
    elif confirm "Remove ${#theme_paths[@]} deployed theme file(s) and the generated theme cache?"; then
        for path in "${theme_paths[@]}"; do
            if [[ $DRY_RUN -eq 1 ]]; then
                blue "  (dry-run) would remove $path"
                continue
            fi
            if [[ ! -e "$path" ]]; then
                yellow "  skip    $path (already gone)"
                continue
            fi
            if rm -rf "$path"; then
                green "  removed  $path"
            else
                red "  failed to remove $path"
            fi
        done
        theme_cache="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would remove generated cache $theme_cache"
        elif [[ -d "$theme_cache" ]]; then
            rm -rf "$theme_cache" && green "  removed  $theme_cache"
        fi
    else
        yellow "  skipped theme files"
    fi
}

uninstall_packages() {
    blue "=== packages ==="
    mapfile -t pkgs < <(manifest_rows PACKAGE | cut -f2 | sort -u)
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        blue "  no PACKAGE rows in manifest — nothing to remove"
        return 0
    fi
    blue "  packages installed by this installer:"
    for p in "${pkgs[@]}"; do blue "    - $p"; done
    if confirm "dnf remove these ${#pkgs[@]} package(s)? (pre-existing packages are never touched)"; then
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would run: dnf remove -y ${pkgs[*]}"
        elif command -v dnf >/dev/null 2>&1; then
            if "${SUDO[@]}" dnf remove -y "${pkgs[@]}" >/dev/null 2>&1; then
                green "  removed ${#pkgs[@]} package(s)"
            else
                red "  dnf remove failed — remove manually: ${pkgs[*]}"
            fi
        else
            yellow "  dnf not found — remove manually: ${pkgs[*]}"
        fi
    else
        yellow "  skipped packages"
    fi
}

uninstall_services() {
    blue "=== services ==="
    mapfile -t services < <(manifest_rows SERVICE | cut -f2 | sort -u)
    if [[ ${#services[@]} -eq 0 ]]; then
        blue "  no SERVICE rows in manifest — nothing to disable"
    elif confirm "Disable ${#services[@]} service(s) enabled by this installer (${services[*]})?"; then
        for svc in "${services[@]}"; do
            if [[ $DRY_RUN -eq 1 ]]; then
                blue "  (dry-run) would run: systemctl disable $svc"
                continue
            fi
            if "${SUDO[@]}" systemctl disable "$svc" >/dev/null 2>&1; then
                green "  disabled $svc"
            else
                red "  failed to disable $svc"
            fi
        done
    else
        yellow "  skipped services"
    fi
}

uninstall_shell() {
    blue "=== login shell ==="
    mapfile -t shell_rows < <(manifest_rows SHELL)
    if [[ ${#shell_rows[@]} -eq 0 ]]; then
        blue "  no SHELL rows in manifest — nothing to revert"
        return 0
    fi
    IFS=$'\t' read -r _ prev_shell _ <<<"${shell_rows[${#shell_rows[@]} - 1]}"
    if [[ -z "$prev_shell" ]]; then
        yellow "  recorded previous shell is empty — revert manually: chsh -s <shell>"
    elif confirm "Restore previous login shell ($prev_shell)?"; then
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would run: chsh -s $prev_shell"
        elif chsh -s "$prev_shell" 2>/dev/null; then
            green "  restored login shell -> $prev_shell"
        else
            red "  failed to chsh back to $prev_shell — run manually: chsh -s $prev_shell"
        fi
    else
        yellow "  kept zsh as login shell"
    fi
}

uninstall_state() {
    blue "=== state ==="
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would offer to remove $MANIFEST_DIR (manifest + this log)"
    elif confirm "Remove the install state dir $MANIFEST_DIR (manifest + uninstall.log)?"; then
        keep_path=""
        if confirm "Keep a copy of uninstall.log somewhere else first?"; then
            keep_path="$HOME/dots-uninstall.log"
            if [[ "${ASSUME_YES:-0}" -ne 1 ]]; then
                read -r -p "  path to save the log to [$keep_path]: " reply || true
                keep_path="${reply:-$keep_path}"
            fi
            cp "$LOG_FILE" "$keep_path"
            green "  log saved -> $keep_path"
        fi
        rm -rf "$MANIFEST_DIR"
        echo "removed $MANIFEST_DIR"
        [[ -n "$keep_path" ]] && echo "log kept at $keep_path"
    else
        yellow "  kept $MANIFEST_DIR"
    fi
}
