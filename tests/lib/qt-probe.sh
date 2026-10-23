#!/usr/bin/env bash
# The REAL-Qt half of tests/qt-theme.sh — SOURCED by it, never run alone
# (tests/lib/ is outside run-tests.sh's depth-1 glob). Uses its caller's SB,
# H, C, K, OUT, DOTS_DIR, check/ok/bad/yellow/blue, engine and writer.
#
# A compiled probe per Qt major, run offscreen with QT_QPA_PLATFORMTHEME=qt5ct
# (what config/zsh/.zshenv sets), is the only proof that the files the template
# and the writer produce are the ones qt5ct and qt6ct actually read. Skipped
# where the build tools, the Qt dev files or either plugin is missing (CI).

QT_PROBE_SRC='#include <QApplication>
#include <QFont>
#include <QIcon>
#include <QPalette>
#include <QTimer>
#include <cstdio>
// once: one line and exit. watch: a line every 250 ms for 8 s.
int main(int c, char **v) {
    QApplication a(c, v);
    auto line = [&] {
        printf("window=%s highlight=%s icons=%s font=%s,%d\n",
            qPrintable(a.palette().color(QPalette::Window).name()),
            qPrintable(a.palette().color(QPalette::Highlight).name()),
            qPrintable(QIcon::themeName()), qPrintable(a.font().family()), a.font().pointSize());
        fflush(stdout);
    };
    if (c < 2) { line(); return 0; }
    int n = 0;
    QTimer t;
    QObject::connect(&t, &QTimer::timeout, [&] { line(); if (++n >= 32) a.quit(); });
    t.start(250);
    return a.exec();
}'

# qt_plugin_present <major> — the qt<major>ct platform theme is installed.
qt_plugin_present() {
    compgen -G "/usr/lib*/qt$1/plugins/platformthemes/libqt$1ct.so" >/dev/null \
        || compgen -G "/usr/lib*/qt/plugins/platformthemes/libqt$1ct.so" >/dev/null \
        || compgen -G "/usr/lib/*/qt$1/plugins/platformthemes/libqt$1ct.so" >/dev/null
}

# qt_run <major> [watch] — the probe, offscreen, in the sandbox.
qt_run() {
    env -i PATH="$PATH" HOME="$H" XDG_CONFIG_HOME="$C" XDG_CACHE_HOME="$K" \
        XDG_STATE_HOME="$H/.local/state" XDG_DATA_HOME="$H/.local/share" \
        QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=qt5ct "$SB/probe$1" ${2:+"$2"} 2>/dev/null
}

# hex <palette> <key> — #rrggbb, lower case, as QColor::name() prints it.
hex() { sed -n "s/^dcol_$2=\"\([0-9A-Fa-f]\{6\}\)\"$/#\1/p" "$1" | tr 'A-F' 'a-f'; }

qt_probe_real() {
    local major dark gruv want got
    blue "==> real Qt (compiled probes, offscreen)"
    if ! command -v g++ >/dev/null 2>&1 || ! command -v pkg-config >/dev/null 2>&1 \
        || ! pkg-config --exists Qt5Widgets Qt6Widgets || ! qt_plugin_present 5 || ! qt_plugin_present 6; then
        yellow "  skip: needs g++, pkg-config, the Qt5 and Qt6 Widgets dev files, qt5ct and qt6ct"
        return 0
    fi
    printf '%s\n' "$QT_PROBE_SRC" >"$SB/probe.cpp"
    for major in 5 6; do
        # shellcheck disable=SC2046 # pkg-config prints separate flags
        g++ -fPIC -o "$SB/probe$major" "$SB/probe.cpp" $(pkg-config --cflags --libs "Qt${major}Widgets") \
            >"$SB/cc$major.log" 2>&1 || {
            bad "the Qt$major probe does not compile: $(grep -m1 error "$SB/cc$major.log")"
            return 0
        }
    done
    dark="$DOTS_DIR/themes/dark/colors.dcol"
    gruv="$DOTS_DIR/themes/gruvbox/colors.dcol"
    rm -rf "$C/qt5ct" "$C/qt6ct" "$H/.local/state"
    engine "$dark"
    writer themes/dark 0
    want="window=$(hex "$dark" pry1) highlight=$(hex "$dark" 1xa7) icons=$(sed -n 's/^icon_theme=//p' "$DOTS_DIR/themes/dark/theme.conf") font=Noto Sans,10"
    for major in 5 6; do
        got="$(qt_run "$major")"
        check "Qt$major reads the palette, icons and font ($got)" test "$got" == "$want"
    done
    # The live path: an open app, then a wallpaper change. Gruvbox's window
    # colour must differ from dark's, or this would prove nothing.
    [[ "$(hex "$gruv" pry1)" != "$(hex "$dark" pry1)" ]] || {
        bad "gruvbox and dark share pry1 — pick another palette for the live check"
        return 0
    }
    for major in 5 6; do
        qt_run "$major" watch >"$SB/watch$major" &
        sleep 1
        engine "$gruv"
        wait $! || true
        check "Qt$major, already open, re-themes on a wallpaper change" \
            grep -q "^window=$(hex "$gruv" pry1) " <(tail -n 1 "$SB/watch$major")
        check "...and it started on the old palette" \
            grep -q "^window=$(hex "$dark" pry1) " <(head -n 1 "$SB/watch$major")
        engine "$dark"
    done
}
