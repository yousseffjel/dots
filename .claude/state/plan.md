# Plan — theming-apply-templates

## Goal
`scripts/theme/apply-templates.sh` — the wallbash-for-X11 template
engine: processes `*.dcol` template files under `config/theme/templates/
{always,theme}/`, substituting `<wallbash_NAME>` placeholders from a
sourced dcol palette and writing the result to each template's declared
target path, optionally running a post-write command.

## Scope
- scripts/theme/apply-templates.sh

## Allowed
- scripts/theme/

## Forbidden
- config/theme/templates/ (sub-task 4 — this sub-task only builds the
  engine; a tiny throwaway test template is used for verification, not
  committed)

## Steps
1. Parse `<always|theme|all>` group args + optional `--palette PATH`
   (defaults to `$cacheDir/colors.dcol`, overridable so a static theme's
   own colors.dcol can drive the same engine — sub-task 6 needs this)
2. Source the palette (`set -a; source; set +a`), build a sed script from
   every `dcol_*` var in scope (`<wallbash_SUFFIX>` -> value), generically
   rather than hardcoding pry1-4/txt1-4/xa1-9 by index
3. Parse each template's line 1 (`target_path|post_command`), expand
   `${confDir}`/`${cacheDir}` tokens via safe string substitution (no
   `eval` — command-injection-conscious, unlike HyDE's own `eval
   target_file=...`)
4. Skip (yellow, not fatal) if the target's parent directory doesn't
   exist — "app not installed" signal, matches HyDE's own check and this
   repo's "missing app -> skip + log" rule
5. Write substituted body atomically (temp file + mv); run post_command
   synchronously, non-fatal on failure (deviation from HyDE's background+
   disown — documented, favors predictability for a dotfiles tool)

## Out of scope
- The actual `*.dcol` templates (sub-task 4)
- reload.sh's ordered/parallel target-process reload (sub-task 5) —
  apply-templates.sh only writes files + fires each template's own
  lightweight post_command

## Risks
- sed replacement-value escaping (`\`, `|`, `&`) — mitigated: explicit
  escape function, tested against values containing all three
- Generic `dcol_*` compgen loop must not misfire on partial-name
  collisions (e.g. `<wallbash_pry1>` matching inside
  `<wallbash_pry1_rgba>`) — mitigated: patterns are the full anchored
  placeholder string including the closing `>`, verified with a test
  template exercising this exact case
