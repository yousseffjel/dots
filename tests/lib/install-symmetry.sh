#!/usr/bin/env bash
# Sandbox helpers for tests/install-uninstall-symmetry.sh — SOURCED, never run
# on its own (tests/lib/ is outside run-tests.sh's depth-1 glob). Reads the
# caller's TMP and DOTS_DIR; defines FAKEBIN, SENTINEL_LOG, DCONF_STORE and
# FLATPAK_STATE.

# Fakes, first on PATH:
#   * git — `clone` makes a tiny non-empty tree instead of touching the
#     network (with a FILE inside, so a snapshot that ignores directories
#     still sees an unclaimed clone); anything else goes to the real git,
#     which manifest_init needs for `rev-parse`.
#   * update-desktop-database — writes <dir>/mimeinfo.cache, the one artefact
#     the real tool leaves, with the real file's header. Faked so the result
#     does not depend on whether desktop-file-utils is on the runner.
#   * dconf + dbus-run-session — a file-backed dconf ($DCONF_STORE); see below.
#   * flatpak — tests/lib/fake-flatpak.sh. Without it the dev host's real
#     flatpak would run here, remote-add included, which goes to the network.
#     Overrides land in the sandbox HOME (the snapshot covers them); remotes
#     in $FLATPAK_STATE, outside it.
#   * sudo dnf systemctl chsh usermod pkill xrdb — SENTINELS. None has any business
#     running during a restore + uninstall of a HOME with no package, service,
#     shell or suckless rows; each records its call and fails, and the test
#     asserts the log stays empty. pkill/xrdb are scope-d decision 8's hazard:
#     the theming engine's post-commands act on the live desktop, which no
#     environment sandbox can contain.
make_fakes() {
    FAKEBIN="$TMP/fakebin"
    SENTINEL_LOG="$TMP/sentinel.log"
    mkdir -p "$FAKEBIN"
    : >"$SENTINEL_LOG"
    local real_git
    real_git="$(command -v git)"
    cat >"$FAKEBIN/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == clone ]]; then
    d="\${*: -1}"
    mkdir -p "\$d/.git" && printf 'ref: refs/heads/main\n' >"\$d/.git/HEAD"
    exit 0
fi
exec "$real_git" "\$@"
EOF
    cat >"$FAKEBIN/update-desktop-database" <<'EOF'
#!/usr/bin/env bash
printf '[MIME Cache]\n' >"${1:?}/mimeinfo.cache"
EOF
    # dconf: a file-backed stand-in for the user's dconf database, so the
    # restore's colour-scheme write is visible and can never reach the real
    # one. write/reset need a "session bus", which env -i never provides —
    # only the dbus-run-session fake does — so the headless-install route
    # (the one a real ssh install takes) is the one exercised.
    DCONF_STORE="$TMP/dconf.store"
    : >"$DCONF_STORE"
    cat >"$FAKEBIN/dconf" <<EOF
#!/usr/bin/env bash
store="$DCONF_STORE"
case "\$1" in
read) awk -F'\t' -v k="\$2" '\$1==k {print \$2}' "\$store" ;;
write | reset)
    [[ -n "\${FAKE_SESSION_BUS:-}" ]] || exit 1
    awk -F'\t' -v k="\$2" '\$1!=k' "\$store" >"\$store.new" && mv "\$store.new" "\$store"
    [[ "\$1" == reset ]] || printf '%s\\t%s\\n' "\$2" "\$3" >>"\$store"
    ;;
*) exit 1 ;;
esac
EOF
    cat >"$FAKEBIN/dbus-run-session" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -- ]] && shift
FAKE_SESSION_BUS=1 exec "$@"
EOF
    FLATPAK_STATE="$TMP/flatpak"
    # shellcheck source=fake-flatpak.sh
    source "$DOTS_DIR/tests/lib/fake-flatpak.sh"
    fake_flatpak "$FAKEBIN/flatpak" "$FLATPAK_STATE"
    local s
    for s in sudo dnf systemctl chsh usermod pkill xrdb; do
        printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\nexit 1\n' "$s" "$SENTINEL_LOG" >"$FAKEBIN/$s"
    done
    chmod +x "$FAKEBIN"/*
}

# Runs a repo script against sandbox HOME $1. All four XDG variables are set,
# never just HOME: global_fn.sh derives the manifest from XDG_STATE_HOME, and
# an inherited real value would point this run at the user's own manifest —
# which uninstall.sh then acts on. No DISPLAY or DBUS either.
in_sandbox() {
    local home="$1"
    shift
    env -i PATH="$FAKEBIN:$PATH" HOME="$home" USER=probe LANG=C.UTF-8 \
        XDG_CONFIG_HOME="$home/.config" XDG_CACHE_HOME="$home/.cache" \
        XDG_STATE_HOME="$home/.local/state" XDG_DATA_HOME="$home/.local/share" \
        bash "$@"
}

# Every non-directory under $1, one per line: files with a content hash,
# symlinks with their target. Directories are deliberately excluded — the
# installer mkdir -p's shared XDG directories (~/.config, ~/.local/share/…)
# that uninstall must not rmdir, since something else may own them too.
snapshot() {
    (cd "$1" && find . \( -type f -o -type l \) -print0 | sort -z \
        | while IFS= read -r -d '' p; do
            if [[ -L "$p" ]]; then
                printf '%s -> %s\n' "$p" "$(readlink "$p")"
            else
                printf '%s %s\n' "$p" "$(sha256sum <"$p" | cut -c1-16)"
            fi
        done)
}
