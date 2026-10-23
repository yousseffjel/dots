#!/usr/bin/env bash
# Sandbox helpers for tests/install-uninstall-symmetry.sh — SOURCED, never run
# on its own (tests/lib/ is outside run-tests.sh's depth-1 glob). Reads the
# caller's TMP and DOTS_DIR; defines FAKEBIN, SENTINEL_LOG, DCONF_STORE,
# FLATPAK_STATE and WALLPAPER_FIXTURE.

# Fakes, first on PATH:
#   * git — `clone` makes a tiny non-empty tree instead of touching the
#     network (with a FILE inside, so a snapshot that ignores directories
#     still sees an unclaimed clone); anything else goes to the real git,
#     which manifest_init needs for `rev-parse`. A clone FROM $TMP is real:
#     that is the wallpaper fixture ($WALLPAPER_FIXTURE, which in_sandbox
#     passes as DOTS_WALLPAPER_REPO), and uninstall-wallpapers.sh asks git
#     whether the clone is unchanged — a stub .git would be kept, correctly.
#   * update-desktop-database — writes <dir>/mimeinfo.cache, the one artefact
#     the real tool leaves, with the real file's header. Faked so the result
#     does not depend on whether desktop-file-utils is on the runner.
#   * dconf + dbus-run-session — a file-backed dconf ($DCONF_STORE); see below.
#   * flatpak — tests/lib/fake-flatpak.sh. Without it the dev host's real
#     flatpak would run here, remote-add included, which goes to the network.
#     Overrides land in the sandbox HOME (the snapshot covers them); remotes
#     in $FLATPAK_STATE, outside it.
#   * sudo dnf xbps-install xbps-remove systemctl chsh usermod pkill xrdb — SENTINELS. None has any business
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
    WALLPAPER_FIXTURE="$TMP/wallpaper-fixture.git"
    make_wallpaper_fixture "$WALLPAPER_FIXTURE"
    # Stand-ins for Void's /usr/share/examples, so restore_pipewire really
    # makes its two links and the round trip proves their removal.
    EXAMPLES_FIXTURE="$TMP/examples"
    mkdir -p "$EXAMPLES_FIXTURE/wireplumber" "$EXAMPLES_FIXTURE/pipewire"
    : >"$EXAMPLES_FIXTURE/wireplumber/10-wireplumber.conf"
    : >"$EXAMPLES_FIXTURE/pipewire/20-pipewire-pulse.conf"
    cat >"$FAKEBIN/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == clone && " \$* " != *" $TMP/"* ]]; then
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
    for s in sudo dnf xbps-install xbps-remove systemctl chsh usermod pkill xrdb; do
        printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\nexit 1\n' "$s" "$SENTINEL_LOG" >"$FAKEBIN/$s"
    done
    chmod +x "$FAKEBIN"/*
}

# A bare repo holding one image, standing in for the wallpaper collection.
make_wallpaper_fixture() {
    local bare="$1" work="$TMP/wallpaper-fixture-work"
    mkdir -p "$work"
    printf 'not really a png\n' >"$work/nature-fixture.png"
    git -C "$work" init -q -b main
    git -C "$work" add .
    git -C "$work" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm fixture
    git clone -q --bare "$work" "$bare"
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
        DOTS_WALLPAPER_REPO="$WALLPAPER_FIXTURE" DOTS_EXAMPLES_DIR="$EXAMPLES_FIXTURE" \
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

# check_specific_claims <manifest> — a restore that skipped one of these steps
# would still round-trip perfectly, so each must leave its own row. Uses the
# caller's pass/fail. Split out of install-uninstall-symmetry.sh at the cap.
check_specific_claims() {
    # The GTK3 Adwaita-dark shim: restore_theme must actually call it.
    if grep -q "^THEME	theme	.*/themes/Adwaita-dark$" "$1"; then
        pass "manifest claims the GTK3 Adwaita-dark shim"
    else
        fail "no THEME row for themes/Adwaita-dark — restore_gtk3_shim did not run"
    fi
    # The PipeWire session links (scope I, I-6): both made, so the round trip
    # proves their removal.
    if [[ "$(grep -c "^LINK	pipewire	" "$1")" == 2 ]]; then
        pass "manifest claims both PipeWire config links"
    else
        fail "expected 2 LINK pipewire rows — restore_pipewire did not run"
    fi
    # The vendored Nerd Font (scope I, D3): restore_theme must extract it, so
    # this round trip proves its removal and not an absence.
    if grep -q "^THEME	theme	.*/fonts/CascadiaCodeNF$" "$1"; then
        pass "manifest claims the vendored Cascadia Code NF"
    else
        fail "no THEME row for fonts/CascadiaCodeNF — restore_font_assets did not run"
    fi
    # The Qt confs (scope K, slot 2): restore_theme must write both, so this
    # round trip proves their removal and not an absence.
    if grep -q "^THEME	theme	.*/qt5ct/qt5ct.conf$" "$1" && grep -q "^THEME	theme	.*/qt6ct/qt6ct.conf$" "$1"; then
        pass "manifest claims both Qt confs"
    else
        fail "no THEME row for qt5ct.conf and qt6ct.conf — theme_write_qt_conf did not run"
    fi
}
