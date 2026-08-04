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
static const Block blocks[] = {
	/*Icon*/	/*Command*/			/*Update Interval*/	/*Update Signal*/
	{"",		"$HOME/.local/bin/dwm-cpu",	2,			1},

	{"",		"$HOME/.local/bin/dwm-mem",	10,			2},

	{"",		"$HOME/.local/bin/dwm-clock",	10,			3},
};

// Delimiter between status commands. An empty string ("") means no delimiter.
// Sized rather than inferred so the -d flag has somewhere to copy into; its
// length is derived in main(), so there is nothing to keep in sync by hand.
static char delim[16] = " | ";
