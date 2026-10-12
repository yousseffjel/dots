# Context — release-0.2.0

## Background
Scope G slot 3 (main: `.claude/tasks/scope-g-release-0.2.0.md`, decisions 1 and 3).

## Prior Decisions
- migrate.sh: run by install-fedora.sh before the install stage; dry-run only
  names hops; non-zero hop pins the manifest; migrations never write the
  manifest version themselves (template rule 3/4).
- README § Versioning: minor = additive, may need a migration.
- CONTRIBUTING § Cut a release: rename [Unreleased], bump VERSION, tag.
- scripts/dots SUBCOMMANDS = single declaration (help, completion, tests).

## References
- scripts/migrate.sh, scripts/migrations/0.1.0-to-0.2.0.sh (template), scripts/version.sh
- tests/changelog-version.sh, tests/dots-dispatch.sh
- Generated headers: suckless/{dwm,dmenu,st,slock}/config.h, suckless/dwmblocks/blocks.h

## Notes
- 0.1.0 was dated at d997704 but never tagged; no tags exist.
