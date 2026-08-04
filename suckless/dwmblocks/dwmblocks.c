#include<errno.h>
#include<fcntl.h>
#include<poll.h>
#include<signal.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<sys/wait.h>
#include<time.h>
#include<unistd.h>
#ifndef NO_X
#include<X11/Xlib.h>
#endif

#ifdef __OpenBSD__
/* OpenBSD has no real-time signals, so blocks map onto SIGUSR1 upwards.
 * Upstream defined SIGPLUS (SIGUSR1+1) for decoding and SIGMINUS (SIGUSR1-1)
 * for registration -- the two never agreed there. One base for both
 * directions is the fix. */
#define SIGBASE			(SIGUSR1 - 1)
#else
#define SIGBASE			SIGRTMIN
#endif
#define LENGTH(X)               (sizeof(X) / sizeof (X[0]))
/* 50 upstream; raised to leave room for status2d colour escapes
 * (^c#RRGGBB^ ... ^d^ costs 13 bytes before any actual text) */
#define CMDLENGTH		64
/* +1 per block for the statuscmd signal byte prepended in getcmd() */
#define STATUSLENGTH (LENGTH(blocks) * (CMDLENGTH + 1) + 1)
#define SHCMDLENGTH		1024
/* Below this many jiffies of poll timeout the tick is not worth taking. */
#define TICKFALLBACK		60

typedef struct {
	char* icon;
	char* command;
	unsigned int interval;
	unsigned int signal;
} Block;

/* One queued signal delivery, handed from sighandler() to the main loop over
 * the self-pipe. */
typedef struct {
	int signal;	/* block signal number, already offset by SIGBASE */
	int button;	/* $BUTTON from dwm's sigqueue(); 0 = plain refresh */
} SigEvent;

#ifndef __OpenBSD__
void dummysighandler(int signum);
#endif
void getcmd(const Block *block, char *output);
void getallcmds(void);
void getcmds(unsigned int time);
void getsigcmds(int signal);
void runclickcmd(int signal, int button);
void drainsignals(void);
void setupsignals(void);
void sighandler(int signum, siginfo_t *si, void *ucontext);
int getstatus(char *str, char *last);
int statusloop(void);
/* signal(2) handlers must be void(int) -- C23 reads the empty parameter list
 * `void f()` as `void f(void)`, which no longer converts implicitly */
void termhandler(int signum);
void pstdout(void);
#ifndef NO_X
void setroot(void);
static void (*writestatus)(void) = setroot;
static int setupX(void);
static Display *dpy;
static int screen;
static Window root;
#else
static void (*writestatus)(void) = pstdout;
#endif

#include "blocks.h"

/* strlen(delim) + 1 -- the byte budget getcmd() reserves at the end of every
 * block. Derived in main() so a -d argument cannot desynchronise it. */
static unsigned int delimLen;
static char statusbar[LENGTH(blocks)][CMDLENGTH + 1] = {0};
static char statusstr[2][STATUSLENGTH];
static volatile sig_atomic_t statusContinue = 1;
/* Self-pipe: sighandler() writes, statusloop() reads. See sighandler(). */
static int sigpipe[2] = { -1, -1 };

//opens process *cmd and stores output in *output
void getcmd(const Block *block, char *output)
{
	char tempstatus[CMDLENGTH] = {0};
	size_t iconlen = strlen(block->icon);
	size_t len;
	int room;
	FILE *cmdf;

	/* Truncate an over-long icon instead of running off tempstatus -- the
	 * icon comes from the config, but a silent overflow is still a trap. */
	if (iconlen + delimLen > sizeof(tempstatus))
		iconlen = sizeof(tempstatus) - delimLen;
	memcpy(tempstatus, block->icon, iconlen);

	if (!(cmdf = popen(block->command, "r")))
		return;
	/* Reserve delimLen bytes at the tail so the delimiter always fits. */
	room = (int)(sizeof(tempstatus) - iconlen - delimLen);
	if (room > 1 && !fgets(tempstatus + iconlen, room, cmdf))
		tempstatus[iconlen] = '\0';	/* command produced no output */
	pclose(cmdf);

	len = strlen(tempstatus);
	//only chop off newline if one is present at the end
	if (len && tempstatus[len - 1] == '\n')
		tempstatus[--len] = '\0';
	/* Append the delimiter only to blocks that actually produced text, so
	 * getstatus() can detect its presence rather than assume it. */
	if (len && delim[0] != '\0')
		memcpy(tempstatus + len, delim, delimLen);

	/* statuscmd: prefix the block's text with its signal byte so dwm can
	 * identify which block was clicked (see buttonpress() in dwm.c) */
	if (block->signal)
		*output++ = (char)block->signal;
	strcpy(output, tempstatus);
}

void getallcmds(void)
{
	for (unsigned int i = 0; i < LENGTH(blocks); i++)
		getcmd(blocks + i, statusbar[i]);
}

void getcmds(unsigned int time)
{
	for (unsigned int i = 0; i < LENGTH(blocks); i++)
		if (blocks[i].interval > 0 && time % blocks[i].interval == 0)
			getcmd(blocks + i, statusbar[i]);
}

void getsigcmds(int signal)
{
	for (unsigned int i = 0; i < LENGTH(blocks); i++)
		if (blocks[i].signal == (unsigned int)signal)
			getcmd(blocks + i, statusbar[i]);
}

/* Re-runs a clicked block's command with $BUTTON set, then lets it signal us
 * back for the refresh. Double-forks so the command is reparented to init:
 * that removes the need for a SIGCHLD handler, which upstream installed and
 * which races with getcmd()'s pclose() over the same child. */
void runclickcmd(int signal, int button)
{
	unsigned int i;
	pid_t parent, pid;
	char shcmd[SHCMDLENGTH];
	char buttonstr[12];

	for (i = 0; i < LENGTH(blocks); i++)
		if (blocks[i].signal == (unsigned int)signal)
			break;
	if (i == LENGTH(blocks))	/* no block owns this signal */
		return;

	parent = getpid();
	if (snprintf(shcmd, sizeof(shcmd), "%s; kill -%d %d", blocks[i].command,
	             (int)(SIGBASE + blocks[i].signal), (int)parent)
	    >= (int)sizeof(shcmd)) {
		fprintf(stderr, "dwmblocks: command for signal %d is too long\n", signal);
		return;
	}
	snprintf(buttonstr, sizeof(buttonstr), "%d", button);

	if ((pid = fork()) < 0) {
		perror("dwmblocks: fork");
		return;
	}
	if (pid == 0) {
		if (fork() == 0) {
			int devnull;
#ifndef NO_X
			if (dpy)
				close(ConnectionNumber(dpy));
#endif
			/* Nothing consumes the click run's stdout -- the value
			 * reaches us through the refresh it signals afterwards.
			 * Under -p it would otherwise be interleaved straight
			 * into the status stream. stderr is left alone so a
			 * broken block script still reports itself. */
			if ((devnull = open("/dev/null", O_WRONLY)) >= 0) {
				dup2(devnull, STDOUT_FILENO);
				if (devnull > STDOUT_FILENO)
					close(devnull);
			}
			setsid();
			setenv("BUTTON", buttonstr, 1);
			execl("/bin/sh", "/bin/sh", "-c", shcmd, (char *)NULL);
			perror("dwmblocks: /bin/sh");
			_exit(EXIT_FAILURE);
		}
		_exit(EXIT_SUCCESS);
	}
	waitpid(pid, NULL, 0);	/* the intermediate child exits immediately */
}

/* Drains every queued signal event and does the work the handler could not.
 * Runs in normal context, so popen/fork/Xlib are all fair game here. */
void drainsignals(void)
{
	SigEvent ev;
	int refresh = 0;

	while (read(sigpipe[0], &ev, sizeof(ev)) == (ssize_t)sizeof(ev)) {
		if (ev.button)
			runclickcmd(ev.signal, ev.button);
		else {
			getsigcmds(ev.signal);
			refresh = 1;
		}
	}
	if (refresh)
		writestatus();
}

void setupsignals(void)
{
	struct sigaction sa;

	memset(&sa, 0, sizeof(sa));
	sa.sa_sigaction = sighandler;
	sa.sa_flags = SA_SIGINFO | SA_RESTART;
	sigemptyset(&sa.sa_mask);
#ifndef __OpenBSD__
	/* initialize all real time signals with dummy handler, and block them
	 * for the duration of ours so two clicks cannot interleave */
	for (int i = SIGRTMIN; i <= SIGRTMAX; i++) {
		signal(i, dummysighandler);
		sigaddset(&sa.sa_mask, i);
	}
#endif
	for (unsigned int i = 0; i < LENGTH(blocks); i++)
		if (blocks[i].signal > 0)
			sigaction(SIGBASE + blocks[i].signal, &sa, NULL);
}

int getstatus(char *str, char *last)
{
	size_t len, dlen;

	strcpy(last, str);
	str[0] = '\0';
	for (unsigned int i = 0; i < LENGTH(blocks); i++)
		strcat(str, statusbar[i]);

	/* Strip one trailing delimiter, but only when it is genuinely there.
	 * Blocks whose command produced nothing do not emit one, and upstream's
	 * unguarded str[strlen(str)-strlen(delim)] underflows past the buffer
	 * once enough of them stay empty. */
	len = strlen(str);
	dlen = strlen(delim);
	if (dlen && len >= dlen && !strcmp(str + len - dlen, delim))
		str[len - dlen] = '\0';

	return strcmp(str, last);//0 if they are the same
}

#ifndef NO_X
void setroot(void)
{
	if (!getstatus(statusstr[0], statusstr[1]))//Only set root if text has changed.
		return;
	XStoreName(dpy, root, statusstr[0]);
	XFlush(dpy);
}

int setupX(void)
{
	dpy = XOpenDisplay(NULL);
	if (!dpy) {
		fprintf(stderr, "dwmblocks: Failed to open display\n");
		return 0;
	}
	screen = DefaultScreen(dpy);
	root = RootWindow(dpy, screen);
	return 1;
}
#endif

void pstdout(void)
{
	if (!getstatus(statusstr[0], statusstr[1]))//Only write out if text has changed.
		return;
	printf("%s\n",statusstr[0]);
	fflush(stdout);
}

static unsigned int gcd(unsigned int a, unsigned int b)
{
	while (b) {
		unsigned int t = b;
		b = a % b;
		a = t;
	}
	return a;
}

/* Tick on the gcd of the configured intervals rather than every second: with
 * 2/10/10s blocks that halves the wakeups for identical output. */
static unsigned int tickinterval(void)
{
	unsigned int g = 0;

	for (unsigned int i = 0; i < LENGTH(blocks); i++)
		if (blocks[i].interval > 0)
			g = gcd(g, blocks[i].interval);
	return g ? g : TICKFALLBACK;	/* signal-only config: wake rarely */
}

static int msuntil(const struct timespec *deadline)
{
	struct timespec now;
	long ms;

	clock_gettime(CLOCK_MONOTONIC, &now);
	ms = (long)(deadline->tv_sec - now.tv_sec) * 1000
	   + (deadline->tv_nsec - now.tv_nsec) / 1000000;
	return ms > 0 ? (int)ms : 0;
}

/* Returns an exit status: a fatal poll() error has to reach the caller, or a
 * supervisor restarting dwmblocks would see a clean exit and not retry. */
int statusloop(void)
{
	struct timespec deadline;
	unsigned int tick = tickinterval();
	unsigned int elapsed = 0;

	setupsignals();
	getallcmds();
	writestatus();

	clock_gettime(CLOCK_MONOTONIC, &deadline);
	while (statusContinue) {
		/* Absolute deadline: the popen() round-trips each tick costs do
		 * not accumulate into clock drift, and -- unlike upstream's
		 * sleep(1), whose return value was discarded -- an incoming
		 * signal cannot shorten the interval. */
		deadline.tv_sec += tick;
		while (statusContinue) {
			struct pollfd pfd;
			int n, timeout = msuntil(&deadline);

			if (timeout == 0)
				break;
			pfd.fd = sigpipe[0];
			pfd.events = POLLIN;
			pfd.revents = 0;
			if ((n = poll(&pfd, 1, timeout)) < 0) {
				if (errno == EINTR)
					continue;
				perror("dwmblocks: poll");
				return 1;
			}
			if (n == 0)
				break;
			drainsignals();
		}
		if (!statusContinue)
			break;
		elapsed += tick;
		getcmds(elapsed);
		writestatus();
	}
	return 0;
}

#ifndef __OpenBSD__
/* this signal handler should do nothing */
void dummysighandler(int signum)
{
	(void)signum;
}
#endif

/* Async-signal-safe by construction: the handler only queues the event on the
 * self-pipe. Everything it used to do inline -- popen(), malloc(), fork() and
 * above all XStoreName()/XFlush() -- is unsafe in signal context, and running
 * it there is what wedges upstream dwmblocks' X connection when a click lands
 * mid-draw. */
void sighandler(int signum, siginfo_t *si, void *ucontext)
{
	SigEvent ev;

	(void)ucontext;
	ev.signal = signum - SIGBASE;
	ev.button = si ? si->si_value.sival_int : 0;
	/* Writes below PIPE_BUF are atomic. A full pipe means the main loop is
	 * already backlogged, so dropping the event beats blocking here. */
	(void)!write(sigpipe[1], &ev, sizeof(ev));
}

void termhandler(int signum)
{
	(void)signum;
	statusContinue = 0;
}

int main(int argc, char** argv)
{
	int status;

	for (int i = 1; i < argc; i++) {//Handle command line arguments
		if (!strcmp("-d", argv[i])) {
			if (i + 1 >= argc) {
				fprintf(stderr, "dwmblocks: -d requires an argument\n");
				return 1;
			}
			/* snprintf, not strncpy: strncpy leaves delim
			 * unterminated when the argument fills it exactly, and
			 * the strlen() below would then read past the buffer. */
			snprintf(delim, sizeof(delim), "%s", argv[++i]);
		} else if (!strcmp("-p", argv[i]))
			writestatus = pstdout;
		else {
			fprintf(stderr, "usage: dwmblocks [-d delimiter] [-p]\n");
			return 1;
		}
	}
	delimLen = (unsigned int)strlen(delim) + 1;

	if (pipe(sigpipe) < 0) {
		perror("dwmblocks: pipe");
		return 1;
	}
	for (int i = 0; i < 2; i++) {
		int fl = fcntl(sigpipe[i], F_GETFL);
		/* Non-blocking: the handler must never stall, and drainsignals()
		 * needs EAGAIN to know the queue is empty. Close-on-exec keeps
		 * the pipe out of every block command we popen(). */
		if (fl < 0 || fcntl(sigpipe[i], F_SETFL, fl | O_NONBLOCK) < 0
		           || fcntl(sigpipe[i], F_SETFD, FD_CLOEXEC) < 0) {
			perror("dwmblocks: fcntl");
			return 1;
		}
	}

#ifndef NO_X
	/* -p needs no display, so do not fail on a headless box. */
	if (writestatus == setroot && !setupX())
		return 1;
#endif
	signal(SIGTERM, termhandler);
	signal(SIGINT, termhandler);
	status = statusloop();
#ifndef NO_X
	if (dpy)
		XCloseDisplay(dpy);
#endif
	return status;
}
