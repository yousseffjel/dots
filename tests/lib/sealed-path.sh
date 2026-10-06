#!/usr/bin/env bash
# Sealed-PATH helpers for the tests/dwm-*.sh scripts — SOURCED, never run on
# its own (tests/lib/ is outside run-tests.sh's depth-1 glob).
#
# Why sealed rather than prepended: a test for "maim is not installed" that
# merely hides a fake falls straight through to a real /usr/bin/maim and
# passes for the wrong reason — three false passes in screenshot-maim-slop
# before the error text gave it away. So the script under test sees ONLY a
# directory of fakes plus symlinks to the real tools it genuinely needs.

# seal_path <dir> <tool>... — creates <dir>, links each named real tool into
# it by ABSOLUTE path (bash's `type -P`; a relative link would dangle), and
# fails loudly if one cannot be found, rather than sealing a PATH that then
# breaks the script under test for a reason that looks like its own bug.
seal_path() {
    local dir="$1" tool real
    shift
    mkdir -p "$dir"
    for tool in "$@"; do
        real="$(type -P "$tool" || true)"
        if [[ -z "$real" || ! -x "$real" ]]; then
            printf '\033[31m%s\033[0m\n' "sealed PATH: real '$tool' not found — cannot build the sandbox" >&2
            return 1
        fi
        ln -sf "$real" "$dir/$tool"
    done
}

# fake <dir> <name> <body> — writes an executable fake whose body is a bash
# snippet. `$LOG` inside it is the shared call log the tests assert on.
#
# The target is removed first. A sealed dir holds SYMLINKS to the real tools,
# and a test that copies one and then fakes a tool in the copy would otherwise
# write through the link into /usr/bin itself — gtk3-adwaita-dark-shim's
# failed-copy case did exactly that to cp, stopped only by file permissions.
fake() {
    local dir="$1" name="$2" body="$3"
    rm -f "$dir/$name"
    printf '#!%s\n%s\n' "$(type -P bash)" "$body" >"$dir/$name"
    chmod 755 "$dir/$name"
}
