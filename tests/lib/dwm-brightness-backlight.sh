#!/usr/bin/env bash
# The mode and backlight (laptop) cases of tests/dwm-brightness.sh — SOURCED
# by it, never run alone (tests/lib/ is outside run-tests.sh's depth-1 glob).
# Uses that file's run/pass/fail/calls helpers and its fake brightnessctl;
# split off at the 250-line cap.

blue "==> mode"
run two mode
if [[ "$OUT" == gamma ]]; then
    pass "no backlight device: gamma, even with brightnessctl installed"
else
    fail "mode without a backlight: '$OUT'"
fi

blue "==> backlight (a laptop)"
echo 'intel_backlight,backlight,4882,51%,9600' >"$TMP/bl"
BL_STATE="$TMP/bl" run two mode
if [[ "$OUT" == backlight ]]; then
    pass "a backlight device: backlight mode"
else
    fail "mode with a backlight: '$OUT'"
fi
BL_STATE="$TMP/bl" run two get
if [[ $RC -eq 0 && "$OUT" == 51 ]]; then
    pass "get reads the backlight percent (51), not xrandr (45)"
else
    fail "backlight get: rc=$RC out='$OUT'"
fi
BL_STATE="$TMP/bl" run two up
if [[ "$OUT" == 61 && "$(calls)" == "brightnessctl --class=backlight -q set 61%" ]]; then
    pass "up sets the backlight to 61% and touches no gamma"
else
    fail "backlight up: out='$OUT' calls=$(calls)"
fi
BL_STATE="$TMP/bl" run two set 3
if [[ "$OUT" == 10 && "$(calls)" == *"set 10%" ]]; then
    pass "the backlight clamps to 10% too — never a black screen"
else
    fail "backlight clamp: out='$OUT' calls=$(calls)"
fi
FAKE_BL_SET_RC=1 BL_STATE="$TMP/bl" run two set 50
if [[ $RC -ne 0 && "$ERR" == *"could not set the backlight"* && "$(calls)" != *"--output"* ]]; then
    pass "a refused backlight write is reported, not swapped for gamma"
else
    fail "backlight write failure: rc=$RC err='$ERR' calls=$(calls)"
fi
echo 'intel_backlight,backlight,4882,oops,9600' >"$TMP/bl-bad"
BL_STATE="$TMP/bl-bad" run two get
if [[ $RC -ne 0 && "$ERR" == *"expected a percent"* ]]; then
    pass "an unparseable brightnessctl line is reported, not read as a value"
else
    fail "bad backlight line: rc=$RC out='$OUT' err='$ERR'"
fi
