/* See LICENSE file for copyright and license details. */

/* appearance */
static const unsigned int borderpx  = 2;        /* border pixel of windows — sole separator in the edge-to-edge layout */
static const unsigned int snap      = 32;       /* snap pixel */
static const unsigned int systraypinning = 0;   /* 0: sloppy systray follows selected monitor, >0: pin systray to monitor X */
static const unsigned int systrayonleft = 0;    /* 0: systray in the right corner, >0: systray on left of status text */
static const unsigned int systrayspacing = 2;   /* systray spacing */
static const int systraypinningfailfirst = 1;   /* 1: if pinning fails, display systray on the first monitor, False: display systray on the last monitor*/
static const int showsystray        = 1;        /* 0 means no systray */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
/* "Cascadia Code NF" is the family Fedora's cascadia-code-nf-fonts actually
 * registers — it packages Microsoft's Nerd Font release, not the
 * ryanoasis/nerd-fonts patch that calls the same typeface "CaskaydiaCove
 * Nerd Font". The bar needs the Nerd glyph range for the status blocks, so
 * a wrong family here falls through fontconfig to plain monospace and every
 * icon renders as tofu. The second entry is the fallback dwm walks when a
 * codepoint is missing from the first. */
static const char *fonts[]          = { "Cascadia Code NF:size=10", "monospace:size=10" };
static const char dmenufont[]       = "Cascadia Code NF:size=10";
static const char col_gray1[]       = "#222222";
static const char col_gray2[]       = "#444444";
static const char col_gray3[]       = "#bbbbbb";
static const char col_gray4[]       = "#eeeeee";
static const char col_cyan[]        = "#005577";
static const char col_focus[]       = "#5294e2"; /* focused-window border accent */
static const char *colors[][3]      = {
	/*               fg         bg         border    */
	[SchemeNorm] = { col_gray3, col_gray1, col_gray2 }, /* unfocused: recessive */
	[SchemeSel]  = { col_gray4, col_cyan,  col_focus }, /* focused: high-contrast accent */
};

/* X resources read at startup (xresources patch) — reload path is
 * restartsig (kill -HUP $(pidof dwm)), which re-execs dwm and so re-reads
 * these on the next xresupdate() call in main(), no in-place hot-reload
 * function needed here. */
static const XResPref resources[] = {
	/* name                    type     address */
	{ "dwm.normbgcolor",      STRING,  &colors[SchemeNorm][ColBg] },
	{ "dwm.normfgcolor",      STRING,  &colors[SchemeNorm][ColFg] },
	{ "dwm.normbordercolor",  STRING,  &colors[SchemeNorm][ColBorder] },
	{ "dwm.selbgcolor",       STRING,  &colors[SchemeSel][ColBg] },
	{ "dwm.selfgcolor",       STRING,  &colors[SchemeSel][ColFg] },
	{ "dwm.selbordercolor",   STRING,  &colors[SchemeSel][ColBorder] },
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* class      instance    title       tags mask     isfloating   isfullscreen   monitor */
	{ "Gimp",     NULL,       NULL,       0,            1,           0,             -1 },
	{ "Firefox",  NULL,       NULL,       1 << 8,       0,           0,             -1 },
};

/* layout(s) */
static const float mfact     = 0.55; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 1;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */
static const int refreshrate = 120;  /* refresh rate (per second) for client move/resize */

static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },    /* first entry is default */
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* key definitions */
#define MODKEY Mod1Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

#define STATUSBAR "dwmblocks"

/* commands */
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
/* No -nb/-nf/-sb/-sf here on purpose: dmenu's xresources patch reads
 * dmenu.background/foreground/selbackground/selforeground, but explicit
 * CLI colour flags override them. Passing them would pin the launcher to
 * these compiled-in colours and it would never follow the theme. With
 * them omitted dmenu uses the themed values when the theming engine has
 * run, and the config.def.h defaults otherwise. */
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont, NULL };
/* alacritty is the primary terminal (GPU-accelerated, themed via
 * config/alacritty/alacritty.toml). st stays vendored, patched and
 * xresources-themed as the fallback for a machine with no working GL —
 * launch it by name from dmenu when that happens. */
static const char *termcmd[]  = { "alacritty", NULL };
static const char *powermenucmd[] = { "dwm-powermenu", NULL };
static const char *clipmenucmd[]  = { "dwm-clipmenu", NULL };

/* --- keybinds that are NOT here ---------------------------------------
 * Media, volume, mic, brightness, the theming engine (wallpaper select /
 * random / theme menu) and the app launchers live in config/sxhkd/sxhkdrc,
 * not in keys[] below. sxhkd is started from the dwm autostart hook.
 *
 * Do not re-add any of them here. dwm and sxhkd both call XGrabKey() on the
 * root window, and a keysym+modifier claimed by both goes to whichever
 * grabbed it first — the loser silently gets nothing, with no error to
 * point at. The two key sets are deliberately disjoint: dwm owns window
 * management plus Mod+p, Mod+Shift+Return, Super+Shift+x and Super+v;
 * sxhkd owns the XF86* keys and the rest of the Super space.
 *
 * The theming binds used to sit here commented out, needing a recompile to
 * enable. As sxhkd bindings they are simply live, and editing them costs
 * Super+Ctrl+r instead of a rebuild — which is the whole point of the
 * split. They moved from Mod+w to Super+w in the process.
 *
 * See KEYBINDINGS.md for the full table across both owners, and
 * docs/THEMING.md for what the theming commands drive.
 * --------------------------------------------------------------------- */

static const Key keys[] = {
	/* modifier                     key        function        argument */
	{ MODKEY,                       XK_p,      spawn,          {.v = dmenucmd } },
	{ MODKEY|ShiftMask,             XK_Return, spawn,          {.v = termcmd } },
	{ MODKEY,                       XK_b,      togglebar,      {0} },
	{ MODKEY,                       XK_j,      focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_k,      focusstack,     {.i = -1 } },
	{ MODKEY,                       XK_i,      incnmaster,     {.i = +1 } },
	{ MODKEY,                       XK_d,      incnmaster,     {.i = -1 } },
	{ MODKEY,                       XK_h,      setmfact,       {.f = -0.05} },
	{ MODKEY,                       XK_l,      setmfact,       {.f = +0.05} },
	{ MODKEY,                       XK_Return, zoom,           {0} },
	{ MODKEY,                       XK_Tab,    view,           {0} },
	{ MODKEY|ShiftMask,             XK_c,      killclient,     {0} },
	{ MODKEY,                       XK_t,      setlayout,      {.v = &layouts[0]} },
	{ MODKEY,                       XK_f,      setlayout,      {.v = &layouts[1]} },
	{ MODKEY,                       XK_m,      setlayout,      {.v = &layouts[2]} },
	{ MODKEY,                       XK_space,  setlayout,      {0} },
	{ MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },
	{ MODKEY|ShiftMask,             XK_f,      togglefullscr,  {0} },
	{ MODKEY,                       XK_0,      view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~0 } },
	{ MODKEY,                       XK_comma,  focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_period, focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,  tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_period, tagmon,         {.i = +1 } },
	/* Dynamic scratchpads: stash whichever window is focused, cycle the
	 * stashed ones back, or drop one out of the set. These stay in dwm
	 * rather than moving to sxhkd (sub-task 4's split) because they call
	 * dwm's own C functions — there is nothing for sxhkd to spawn. */
	{ MODKEY|ShiftMask,             XK_minus,  scratchpad_hide,   {0} },
	{ MODKEY,                       XK_minus,  scratchpad_show,   {0} },
	{ MODKEY,                       XK_equal,  scratchpad_remove, {0} },
	TAGKEYS(                        XK_1,                      0)
	TAGKEYS(                        XK_2,                      1)
	TAGKEYS(                        XK_3,                      2)
	TAGKEYS(                        XK_4,                      3)
	TAGKEYS(                        XK_5,                      4)
	TAGKEYS(                        XK_6,                      5)
	TAGKEYS(                        XK_7,                      6)
	TAGKEYS(                        XK_8,                      7)
	TAGKEYS(                        XK_9,                      8)
	{ MODKEY|ShiftMask,             XK_q,      quit,           {0} },
	{ MODKEY|ControlMask|ShiftMask, XK_q,      quit,           {1} },
	{ Mod4Mask|ShiftMask,           XK_x,      spawn,          {.v = powermenucmd } },
	{ Mod4Mask,                     XK_v,      spawn,          {.v = clipmenucmd } },
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button1,        sigstatusbar,   {.i = 1} },
	{ ClkStatusText,        0,              Button2,        sigstatusbar,   {.i = 2} },
	{ ClkStatusText,        0,              Button3,        sigstatusbar,   {.i = 3} },
	/* Scroll over the status bar. .i is the button number the statuscmd patch
	 * exports as $BUTTON to the clicked block; the block's own signal is
	 * supplied by the patch, so nothing here is per-block. Without these two
	 * rows a scroll on the bar is discarded before any block sees it --
	 * dwm-vol's 5% steps are the first user (roster Epic sub-task 7). */
	{ ClkStatusText,        0,              Button4,        sigstatusbar,   {.i = 4} },
	{ ClkStatusText,        0,              Button5,        sigstatusbar,   {.i = 5} },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};

