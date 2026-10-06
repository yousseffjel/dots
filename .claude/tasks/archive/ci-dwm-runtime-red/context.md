# Context — ci-dwm-runtime-red

## Background
User asked "what is next"; CI on main was found red since 2026-08-14 (public
GitHub API: last CI success 97c3dbb). Failing step: build-suckless "Run dwm
under Xvfb", exit 127 on fedora:latest and fedora:43.

## Prior Decisions
- scope-d locked decision 3: dwm-runtime.sh runs inside build-suckless.
- The test's runtime-only deps are NOT in packages/build.lst (ci.yml comment).
- procps-ng is declared in packages/desktop.lst (real installs have pgrep).

## References
- tests/dwm-runtime.sh:96 cleanup(); tests/lib/dwm-runtime-checks.sh:160 check_restartsig
- suckless/dwm/dwm.c:1836 run() blocks in XNextEvent; :2312 sighup -> quit -> running=0
- memory: bash-process-gotchas-traps-pgrep (set -e in EXIT traps)

## Notes
- Reproduced locally: `docker run fedora:latest`, CI steps, all checks pass,
  then `pkill -f "xterm -class ..."` -> 127 in the trap -> exit=127.
- Same run: restartsig WARN "SIGHUP never triggered a restart".
- Job logs need auth (403); check-run annotations are public.
