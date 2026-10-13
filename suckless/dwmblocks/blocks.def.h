// Modify this file to change what commands output to your statusbar, and
// recompile using the make command.
//
// Scripts live in ./scripts and are installed to ~/.local/bin by `make
// install-scripts`. They are referenced by absolute path ($HOME is expanded by
// /bin/sh, which dwmblocks uses to run each command) so the blocks do not
// depend on PATH being set up inside the X session.
//
// Colour markup (^c#RRGGBB^ ... ^d^) is emitted by the scripts themselves and
// rendered by the status2d patch in dwm. The palette they share lives in
// ./scripts/dwm-colors. That is also why every icon below is empty: the label
// has to sit *inside* the colour escape, so the scripts print their own.
//
// A non-zero signal is required for a block to be clickable: dwm's statuscmd
// patch prefixes each block with its signal byte, then sends SIGRTMIN+signal
// with the button number in $BUTTON.
//
// INTERVAL 0 MEANS SIGNAL-DRIVEN ONLY -- never polled. getallcmds() still runs
// every block once at startup, so those blocks are populated immediately; from
// then on they refresh solely when something sends their signal: every
// interval-0 block below is paired with a key in config/sxhkd/sxhkdrc that fires
// `pkill -RTMIN+<sig> dwmblocks` after changing the value. Break that pairing and
// the block silently never updates again -- tests/blocks-info.sh fails the build
// instead, reading both files, so the list is not restated here. Pick a new
// block's signal from the ones the table below does not use.
//
// Signal 11 belongs to dwm-net (added 2026-10-05, after the clock took 10),
// so it sits out of order in the column: the number only has to be unique.
//
// dwm-battery (13, scope-h 2026-10-13) prints nothing without a system
// battery, so on a desktop it takes no space and adds no delimiter.
//
// SIGNALS ARE POSITION-INDEPENDENT BUT NOT FREE TO RENUMBER. Anything that
// sends SIGRTMIN+n has to move with the number here, so grep for `RTMIN+` in
// config/ before touching this column.
static const Block blocks[] = {
	/*Icon*/	/*Command*/					/*Update Interval*/	/*Update Signal*/
	{"",		"$HOME/.local/bin/dwm-updates",			3600,			1},

	{"",		"$HOME/.local/bin/dwm-disk",			300,			2},

	{"",		"$HOME/.local/bin/dwm-temp",			5,			3},

	{"",		"$HOME/.local/bin/dwm-cpu",			2,			4},

	{"",		"$HOME/.local/bin/dwm-mem",			10,			5},

	{"",		"$HOME/.local/bin/dwm-brightness-block",	0,			6},

	{"",		"$HOME/.local/bin/dwm-mic",			0,			7},

	{"",		"$HOME/.local/bin/dwm-vol",			0,			8},

	{"",		"$HOME/.local/bin/dwm-net",			30,			11},

	{"",		"$HOME/.local/bin/dwm-bluetooth",		30,			9},

	{"",		"$HOME/.local/bin/dwm-dnd",			0,			12},

	{"",		"$HOME/.local/bin/dwm-battery",			60,			13},

	{"",		"$HOME/.local/bin/dwm-clock",			60,			10},
};

// Delimiter between status commands. An empty string ("") means no delimiter.
// Sized rather than inferred so the -d flag has somewhere to copy into; its
// length is derived in main(), so there is nothing to keep in sync by hand.
static char delim[16] = " | ";
