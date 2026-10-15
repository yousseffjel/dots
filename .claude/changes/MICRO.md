# Micro changes

One line per Micro task (1 file, <=20 lines), per /commit step 2.

2026-09-28 markdownlint-single-ignore: the markdownlint pre-commit hook's exclude: regex duplicated .markdownlintignore; it now passes --ignore-path .markdownlintignore like tests/lint.sh (verified with uvx pre-commit both ways: ignored file with a violation passes, unignored one fails). Reviewer READY.
2026-10-15 ci-void-branch: ci.yml and install-container.yml also run on pushes to the void branch (scope I), so pushing the port runs CI; both parsed with PyYAML (push branches [main, void]).
