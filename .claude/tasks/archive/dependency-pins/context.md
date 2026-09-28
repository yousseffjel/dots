# Context — dependency-pins

## Background
MASTER_PLAN HyDE-parity queue item; user asked to finish all code items 2026-09-28.

## Prior Decisions
- Queue entry: scope "what can be automated" before adopting a tool; may be one Dependabot stanza + a manual sweep.

## References
- https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories (pre-commit listed, version updates only)

## Notes
- Pinned pairs: SHELLCHECK_VERSION(+SHA256)/shellcheck-py rev, SHFMT_VERSION/pre-commit-shfmt rev (v3.13.1 vs v3.13.1-1), MARKDOWNLINT_VERSION/markdownlint-cli rev.
- actions/checkout@v7 and actions/cache@v6.1.0 verified to exist on their release pages 2026-09-28.
- Neither docker nor github-actions ecosystem updates a `container:` matrix tag.
