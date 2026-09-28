# Micro changes

One line per Micro task (1 file, <=20 lines), per /commit step 2.

2026-09-28 markdownlint-single-ignore: the markdownlint pre-commit hook's exclude: regex duplicated .markdownlintignore; it now passes --ignore-path .markdownlintignore like tests/lint.sh (verified with uvx pre-commit both ways: ignored file with a violation passes, unignored one fails). Reviewer READY.
