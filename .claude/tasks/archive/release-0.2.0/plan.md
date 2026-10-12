# Plan — release-0.2.0

## Goal
Scope G slot 3: cut 0.2.0 so an existing install upgrades in one step —
`dots update` (pull + re-run the installer), a real 0.1.0-to-0.2.0 migration
for stale generated headers (decision 1), the first tests of migrate.sh,
then CHANGELOG [0.2.0] and VERSION. Tags are asked for, never assumed.

## Scope
- scripts/**
- tests/**
- config/zsh/completions/**
- VERSION
- *.md
- docs/**
- .claude/tasks/release-0.2.0/**
- .claude/state/**

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. tests/migrate.sh: migrate.sh chain on a sandbox manifest (no-op fresh, hop + version bump, dry-run untouched, failing hop pins version, ambiguous path errors).
2. scripts/migrations/0.1.0-to-0.2.0.sh: each generated config.h / blocks.h — absent or equal to its *.def.h: skip; equal to ANY past *.def.h in git: back up *.pre-0.2.0 + remove (rebuild regenerates); edited: keep, print the *.def.h diff to merge; no git: report only. Tests in a sandbox git repo.
3. dots update (scripts/update.sh + SUBCOMMANDS row): refuse a dirty tree, a detached HEAD, no upstream, a non-fast-forward; git pull --ff-only; exec install-fedora.sh "$@". tests/dots-update.sh on sandbox repos.
4. Release cut: CHANGELOG [Unreleased] -> [0.2.0] - 2026-10-12 (+ empty [Unreleased], dots update line), VERSION 0.2.0, README Versioning (template note), README/KEYBINDINGS upgrade text.
5. Verify: suite, lint, mutations on copies; migration dry-check against this repo's own generated headers (read-only).

## Out of scope
- Creating or pushing git tags (ask after merge: v0.1.0 at d997704? v0.2.0)
- Migrating user-owned autostart.sh/.xinitrc (rule 6: the installer prints)

## Risks
- Deleting an edited config.h — only byte-identical-to-history is removed, always backed up first
- Tests touching the real repo/manifest — sandbox git repos + all XDG vars
