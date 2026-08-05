/* user and group to drop privileges to */
static const char *user  = "nobody";
static const char *group = "nogroup";

static const char *colorname[NUMCOLS] = {
	[INIT] =   "black",     /* after initialization */
	[INPUT] =  "#005577",   /* during input */
	[FAILED] = "#CC3333",   /* wrong password */
};

/* X resources read once at launch (xresources patch) — slock exits and
 * respawns per lock, so a fresh read at startup is the only reload path
 * it needs. */
static const ResourcePref resources[] = {
	/* name          type     address */
	{ "initcolor",  STRING,  &colorname[INIT] },
	{ "inputcolor", STRING,  &colorname[INPUT] },
	{ "failedcolor", STRING, &colorname[FAILED] },
};

/* treat a cleared input like a wrong password (color) */
static const int failonclear = 1;
