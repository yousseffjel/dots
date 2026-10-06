#!/usr/bin/env bash
# A fake `flatpak` for tests/flatpak-integration.sh and the install/uninstall
# symmetry sandbox — SOURCED, never run on its own (tests/lib/ is outside
# run-tests.sh's depth-1 glob).
#
# fake_flatpak <path> <statedir> writes an executable at <path> covering the
# five subcommands the shipped code calls, with output shaped like flatpak
# 1.18's (probed 2026-10-06 against the real binary in a sandboxed HOME):
#   * override --user --filesystem=E | --nofilesystem=P — rewrites the REAL
#     file, $XDG_DATA_HOME/flatpak/overrides/global, the way flatpak does:
#     [Context] first, filesystems= ";"-terminated, one entry per path (a new
#     mode replaces the old one), a blank line before any other group.
#   * remotes --user --columns=name — one per line; a lone newline when empty.
#   * remote-add --user --if-not-exists N URL — fails when FAKE_OFFLINE is set.
#   * remote-delete --user N — refuses while <statedir>/origins lists N, as
#     flatpak refuses a remote that installed refs come from.
#   * list --user --columns=origin — <statedir>/origins, nothing when empty.
# Remotes and origins live in <statedir>, OUTSIDE the sandbox HOME: the real
# flatpak keeps them under ~/.local/share/flatpak/repo, which uninstall
# deliberately leaves (see uninstall-flatpak.sh), and the symmetry snapshot
# must not see a file the real binary would not leave either.
# Every call is appended to <statedir>/calls.
# tests/flatpak-integration.sh runs the same round trip against a real flatpak
# when one is installed, which is what keeps this format honest.
fake_flatpak() {
    local path="$1" st="$2"
    mkdir -p "$st"
    touch "$st/remotes" "$st/origins" "$st/calls"
    # An absolute shebang, like fake() in sealed-path.sh: a sealed PATH has no
    # bash on it for env to find.
    cat >"$path" <<EOF
#!$(type -P bash)
st="$st"
EOF
    cat >>"$path" <<'EOF'
echo "flatpak $*" >>"$st/calls"
sub="$1"
shift
case "$sub" in
remotes) if [[ -s "$st/remotes" ]]; then cat "$st/remotes"; else echo; fi ;;
list) cat "$st/origins" ;;
remote-add)
    [[ -z "${FAKE_OFFLINE:-}" ]] || exit 1
    name="${*: -2:1}"
    grep -qx "$name" "$st/remotes" || echo "$name" >>"$st/remotes"
    ;;
remote-delete)
    name="${*: -1}"
    grep -qx "$name" "$st/origins" && exit 1
    grep -vx "$name" "$st/remotes" >"$st/remotes.new" || true
    mv "$st/remotes.new" "$st/remotes"
    ;;
override)
    e="${*: -1}"
    case "$e" in
    --filesystem=*) e="${e#--filesystem=}" ;;
    --nofilesystem=*) e="!${e#--nofilesystem=}" ;;
    *) exit 1 ;;
    esac
    p="${e#!}"; p="${p%:ro}"; p="${p%:rw}"; p="${p%:create}"
    f="${XDG_DATA_HOME:?}/flatpak/overrides/global"
    mkdir -p "${f%/*}"
    [[ -f "$f" ]] || printf '[Context]\nfilesystems=\n' >"$f"
    grep -qx '\[Context\]' "$f" || { printf '[Context]\nfilesystems=\n\n'; cat "$f"; } >"$f.new"
    [[ -f "$f.new" ]] && mv "$f.new" "$f"
    awk -v e="$e" -v p="$p" '
        function path(x) { sub(/^!/, "", x); sub(/:(ro|rw|create)$/, "", x); return x }
        /^\[/ { if (ctx && !done) { print "filesystems=" e ";"; done = 1 } ctx = ($0 == "[Context]") }
        ctx && /^filesystems=/ {
            n = split(substr($0, 13), a, ";"); out = ""
            for (i = 1; i <= n; i++) if (a[i] != "" && path(a[i]) != p) out = out a[i] ";"
            print "filesystems=" out e ";"; done = 1; next
        }
        { print }
        END { if (ctx && !done) print "filesystems=" e ";" }' "$f" >"$f.new"
    mv "$f.new" "$f"
    ;;
*) exit 1 ;;
esac
EOF
    chmod 755 "$path"
}
