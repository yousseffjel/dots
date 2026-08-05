/* See LICENSE file for copyright and license details. */
/* Default settings; can be overriden by command line. */

static int topbar = 1;                      /* -b  option; if 0, dmenu appears at bottom     */
static int fuzzy  = 1;                      /* -F  option; if 0, dmenu doesn't use fuzzy matching */

/* Centered floating box (center patch).
 * `centered` is the default here — pass -nc for the classic edge-to-edge bar.
 * The box widens to fit its longest item and never shrinks below min_width, so
 * short menus stay a comfortable target instead of collapsing to the prompt.
 * menu_height_ratio divides the leftover vertical space: 2.0 is dead centre,
 * larger values ride higher up the screen. 3.0 puts it in the upper third,
 * roughly where the eye already is. */
static int centered            = 1;         /* -c / -nc option */
static unsigned int min_width  = 700;       /* minimum width when centered */
static const float menu_height_ratio = 3.0f;

/* Window border (border patch); -bw overrides. Drawn in the SchemeSel
 * background, so -sb recolours the frame along with the selection and the box
 * keeps a visible edge against a busy wallpaper. Matches dwm's borderpx = 2. */
static unsigned int border_width = 2;

/* -fn option overrides fonts[0]; default X11 font or font set.
 * Kept in step with dwm's `dmenufont` — dwm's dmenucmd passes -fn explicitly,
 * so this value is what a bare `dmenu` call on the terminal picks up.
 * Note: do not add a colour-emoji fallback here. Xft hands dmenu a colour
 * bitmap glyph it cannot render and the process dies with BadLength unless the
 * allow-color-font patch is applied on top. */
static const char *fonts[] = {
	"monospace:size=10"
};
static const char *prompt      = NULL;      /* -p  option; prompt to the left of input field */

/* Compiled-in fallback palette, mirroring suckless/dwm/config.def.h so the
 * two agree before the theming engine has ever run. Once it has, these are
 * superseded at startup by the dmenu.background/foreground/selbackground/
 * selforeground X resources (see patches/PATCHES.md). Nothing passes
 * -nb/-nf/-sb/-sf any more — dwm's dmenucmd, dwm-powermenu and dwm-clipmenu
 * all deliberately omit them, because those flags would override the
 * resources and pin the menu to these values forever. */
static const char *colors[SchemeLast][2] = {
	/*     fg         bg       */
	[SchemeNorm] = { "#bbbbbb", "#222222" },
	[SchemeSel] = { "#eeeeee", "#005577" },
	[SchemeOut] = { "#000000", "#00ffff" },
};

/* X resources read at startup (xresources patch) — dmenu is short-lived
 * (one invocation per launch), so there is no live reload: each new dmenu
 * process just re-reads the X resource database. */
static const XResPref resources[] = {
	/* name                  type     address */
	{ "dmenu.background",    STRING,  &colors[SchemeNorm][ColBg] },
	{ "dmenu.foreground",    STRING,  &colors[SchemeNorm][ColFg] },
	{ "dmenu.selbackground", STRING,  &colors[SchemeSel][ColBg] },
	{ "dmenu.selforeground", STRING,  &colors[SchemeSel][ColFg] },
};
/* -l option; if nonzero, dmenu uses vertical list with given number of lines.
 * A vertical list is what makes the centered box read as a box rather than a
 * stray single row; 10 rows fits a 1080p screen without dominating it. */
static unsigned int lines      = 10;

/* -h option; minimum height of a menu line (lineheight patch).
 * drw centres the glyphs in the row, so this is pure breathing room: 28px on a
 * ~10pt font gives roughly the padding a modern launcher uses. 0 means "as
 * tall as the font needs", which is cramped on hidpi. min_lineheight is the
 * floor -h will accept, guarding against an unreadable `-h 1`. */
static unsigned int lineheight = 28;
static unsigned int min_lineheight = 8;

/*
 * Characters not considered part of a word while deleting words
 * for example: " /?\"&[]"
 */
static const char worddelimiters[] = " ";
