PREFIX  := /usr/local
CC      := cc
CFLAGS  := -pedantic -Wall -Wextra -Wno-deprecated-declarations -Os
LDFLAGS := -lX11
# Block scripts are per-user config, so they go to the user's bin rather than
# PREFIX -- blocks.def.h references them there by absolute path.
SCRIPTDIR := ${HOME}/.local/bin

# FreeBSD (uncomment)
#LDFLAGS += -L/usr/local/lib -I/usr/local/include
# # OpenBSD (uncomment)
#LDFLAGS += -L/usr/X11R6/lib -I/usr/X11R6/include

all: options dwmblocks

options:
	@echo dwmblocks build options:
	@echo "CFLAGS  = ${CFLAGS}"
	@echo "LDFLAGS = ${LDFLAGS}"
	@echo "CC      = ${CC}"

# blocks.def.h is deliberately not a prerequisite: blocks.h is the live config
# and regenerating it from a newer default would silently discard local edits.
# Delete blocks.h by hand to pick up changes to blocks.def.h.
dwmblocks: dwmblocks.c blocks.h
	${CC} -o $@ dwmblocks.c ${CFLAGS} ${LDFLAGS}

# Headless variant: prints the status line to stdout instead of setting the X
# root window name, and links no X libraries. Useful for testing blocks over
# ssh or on a server.
dwmblocks-nox: dwmblocks.c blocks.h
	${CC} -o $@ dwmblocks.c ${CFLAGS} -DNO_X

blocks.h:
	cp blocks.def.h $@

clean:
	rm -f *.o *.gch dwmblocks dwmblocks-nox

install: dwmblocks
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f dwmblocks ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/dwmblocks

uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/dwmblocks

# Globbed rather than listed, so adding scripts/dwm-foo needs no Makefile edit.
# dwm-colors is sourced by the others, not executed, hence the 644.
#
# Both targets derive their file list from scripts/ rather than globbing
# ${SCRIPTDIR}. That matters for uninstall-scripts: ${SCRIPTDIR} is ~/.local/bin,
# so `rm -f ${SCRIPTDIR}/dwm-*` would take any dwm-* script the user wrote
# themselves along with ours. Deriving from the source directory removes
# exactly what install-scripts put there and nothing else.
install-scripts:
	mkdir -p ${SCRIPTDIR}
	cp -f scripts/dwm-* ${SCRIPTDIR}
	@for f in scripts/dwm-*; do chmod 755 "${SCRIPTDIR}/`basename $$f`"; done
	chmod 644 ${SCRIPTDIR}/dwm-colors

uninstall-scripts:
	@for f in scripts/dwm-*; do rm -f "${SCRIPTDIR}/`basename $$f`"; done

.PHONY: all options clean install uninstall install-scripts uninstall-scripts
