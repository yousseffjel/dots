#!/usr/bin/env bash
# "install" stage, package half: installs the C toolchain group, three tiers
# of dnf packages, the clipmenu/clipnotify COPR (backs dwm-clipmenu, Super+v),
# and the fdfind -> fd shim. The suckless build (dwm/st/dmenu/dwmblocks/slock)
# is the other half of the "install" stage — see install-suckless.sh, which
# owns packages/build.lst and installs those deps itself.
#
# The three tiers this script reads, in install order:
#
#   core.lst    hard-fail. The installer's own next step breaks without it —
#               git for the zinit/TPM clones, zsh for the chsh step.
#   desktop.lst never aborts, but each failure is repeated in a red closing
#               summary with the consequence taken from the package's own
#               trailing comment. These are the ones whose absence would
#               otherwise be SILENT: a dead keybind, a daemon that never
#               starts, a theming engine that cannot run.
#   extra.lst   never aborts. Applications and conveniences; failures are
#               listed in the closing summary as a single yellow line.
#
# Re-runnable: every dnf install is idempotent.
#
# usage: install-pkg.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$DOTS_DIR/packages"
source "$SCRIPT_DIR/global_fn.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            echo "usage: install-pkg.sh [--dry-run]"
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            exit 1
            ;;
    esac
done

if [[ $DRY_RUN -eq 0 ]]; then
    manifest_init \
        "$(tr -d '[:space:]' <"$DOTS_DIR/VERSION" 2>/dev/null || echo unknown)" \
        "$(git -C "$DOTS_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

if ! command -v dnf >/dev/null 2>&1; then
    red "dnf not found — this script targets Fedora."
    exit 1
fi

SUDO=()
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        red "sudo not found and not running as root."
        exit 1
    fi
    SUDO=(sudo)
fi

# Tier machinery: read_pkg_list, dnf_install, install_tier, install_summary
# and the desktop.lst consequence map. Split out to stay under the 250-line
# cap — see that file's header.
source "$SCRIPT_DIR/install-pkg-tiers.sh"

blue "==> installing C Development Tools and Libraries (group)"
if [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would install group: C Development Tools and Libraries"
elif ! "${SUDO[@]}" dnf group install -y "C Development Tools and Libraries" 2>/dev/null; then
    if ! "${SUDO[@]}" dnf groupinstall -y "C Development Tools and Libraries" 2>/dev/null; then
        yellow "  skipped (group unavailable under this dnf) — individual packages below still cover the build toolchain"
    fi
fi

load_consequences

install_tier "installing required packages (hard-fail — later stages depend on them)" \
    "$PACKAGES_DIR/core.lst" hard
install_tier "installing desktop-critical packages (never aborts; failures are repeated at the end)" \
    "$PACKAGES_DIR/desktop.lst" desktop
install_tier "installing optional packages (best-effort)" \
    "$PACKAGES_DIR/extra.lst" extra

# clipmenu + clipnotify back dwm-clipmenu (Super+v) and aren't in Fedora's
# official repos — enabling this COPR is a deliberate exception to this
# repo's usual "COPR is opt-in, never auto-enabled" rule, since the feature
# is core to the desktop rather than a nice-to-have.
blue "==> enabling skidnik/clipmenu COPR"
if [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would enable COPR skidnik/clipmenu and install clipmenu, clipnotify"
elif "${SUDO[@]}" dnf copr enable -y skidnik/clipmenu; then
    # Not in desktop.lst — these two come from a COPR, not the official
    # repos, so they cannot live in a list the dry-run validates against
    # enabled repos. They get the same treatment by hand: a failure here is
    # a silently dead keybind, which is the whole point of the red summary.
    for pkg in clipmenu clipnotify; do
        already=0
        rpm -q "$pkg" >/dev/null 2>&1 && already=1
        if "${SUDO[@]}" dnf install -y "$pkg" >/dev/null 2>&1; then
            green "  installed: $pkg"
            if [[ $already -eq 0 ]]; then
                manifest_append_row PACKAGE "$pkg"
            fi
        else
            CONSEQUENCE["$pkg"]="clipboard history is dead: the dwm-clipmenu keybind (Super+v) opens nothing"
            yellow "  FAILED: $pkg — ${CONSEQUENCE[$pkg]}"
            FAILED_DESKTOP+=("$pkg")
        fi
    done
else
    CONSEQUENCE[clipmenu]="COPR skidnik/clipmenu could not be enabled: install clipmenu and clipnotify by hand or Super+v does nothing"
    yellow "  FAILED: skidnik/clipmenu COPR — ${CONSEQUENCE[clipmenu]}"
    FAILED_DESKTOP+=(clipmenu)
fi

# starship is the prompt (config/zsh/conf.d/99-prompt.zsh reads
# config/starship/starship.toml) but Fedora does not package it — it was
# dropped around F37, verified 2026-08-06 against packages.fedoraproject.org.
# Installing from the upstream script is a deliberate, user-approved choice
# over the atim/starship COPR. Two consequences worth knowing:
#
#   1. dnf neither upgrades nor removes it. Re-run `starship upgrade`, or the
#      command below, yourself.
#   2. No manifest row is written, so `uninstall.sh` will NOT remove it. A
#      PACKAGE row would be actively harmful — uninstall_packages() passes
#      every PACKAGE value to a single `dnf remove`, and one un-removable name
#      makes that call fail, taking every other package down with it.
#
#      A SCRIPT row was rejected for a second reason that no longer holds: it
#      would have filed starship under a prompt reading "dwmblocks block
#      scripts". That prompt was generalised on 2026-08-13 (it now counts rows
#      instead of naming one kind), so a SCRIPT row would read correctly today.
#      Adding one is a behaviour change — uninstall would start deleting a
#      binary the user may upgrade independently via `starship upgrade` — so it
#      is left as a deliberate open choice, not done in passing. Until then:
#        rm -f ~/.local/bin/starship
#
# Best-effort: on failure 99-prompt.zsh falls back to its built-in prompt,
# which is degraded but perfectly usable, so this never aborts the run.
STARSHIP_BIN="$HOME/.local/bin"
blue "==> installing starship (upstream script — not in Fedora repos)"
if command -v starship >/dev/null 2>&1; then
    green "  already installed: starship ($(command -v starship))"
elif [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would install starship to $STARSHIP_BIN via https://starship.rs/install.sh"
elif ! command -v curl >/dev/null 2>&1; then
    yellow "  skipped — curl not available; install starship manually or use: dnf copr enable atim/starship"
else
    mkdir -p "$STARSHIP_BIN"
    # --proto '=https' --tlsv1.2 refuse plaintext and downgraded transports;
    # -f makes curl exit non-zero on an HTTP error instead of piping an error
    # page into sh.
    if curl --proto '=https' --tlsv1.2 -sSf https://starship.rs/install.sh \
        | sh -s -- --yes --bin-dir "$STARSHIP_BIN" >/dev/null 2>&1; then
        green "  installed: starship -> $STARSHIP_BIN/starship"
        yellow "  note: not dnf-managed — uninstall.sh will not remove it (rm -f $STARSHIP_BIN/starship)"
    else
        yellow "  could not install starship — the shell falls back to its built-in prompt."
        yellow "  retry manually, or let dnf own it: dnf copr enable atim/starship && dnf install starship"
    fi
fi

# Fedora's fd-find package ships its binary as `fdfind` (name clash with
# another package, same as Debian/Ubuntu) — shim it under ~/.local/bin so
# the configs' `command -v fd` checks succeed.
if [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would shim fdfind -> ~/.local/bin/fd (if fdfind present and fd absent)"
else
    mkdir -p "$HOME/.local/bin"
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
        green "shim    fdfind -> ~/.local/bin/fd"
    fi
fi

install_summary
green "✓ package stage complete"
