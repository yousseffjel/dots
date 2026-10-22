#!/usr/bin/env bash
# dwm_build_stale — SOURCED by tests/dwm-runtime.sh and tests/dwm-multimon.sh
# (and tests/dwm-build-fresh.sh, its own test). Lives under tests/lib/ so the
# depth-1 `tests/*.sh` glob never runs it as a test.
#
# Those two tests run the built suckless/dwm/dwm, and nothing rebuilds it
# between a source change and a local run: a binary older than dwm.c tests
# the old code, failing correct changes and passing broken ones. They FAIL on
# a stale build rather than skip, so a green suite cannot hide it.

# dwm_build_stale <binary> — exit 0 and print the first reason (with the
# command that fixes it) when the binary is older than a source beside it;
# exit 1 when it is current. Sources are the build directory's own *.c, *.h,
# config.mk and Makefile (not patches/, a record; not *.o or backups).
dwm_build_stale() {
    local bin="$1" dir src
    dir="$(dirname "$bin")"
    # config.h's make rule has no prerequisite, so it is never regenerated:
    # a newer config.def.h needs it removed first, or the rebuild compiles
    # the old config.
    if [[ -e "$dir/config.h" && "$dir/config.def.h" -nt "$dir/config.h" ]]; then
        echo "config.def.h is newer than config.h, which make never regenerates: run  rm $dir/config.h && make -C $dir"
        return 0
    fi
    src="$(find "$dir" -maxdepth 1 \( -name '*.c' -o -name '*.h' -o -name config.mk -o -name Makefile \) \
        -newer "$bin" -printf '%f\n' | sort | sed -n 1p)"
    [[ -n "$src" ]] || return 1
    echo "$src is newer than the built dwm: run  make -C $dir"
}
