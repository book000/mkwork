# Copilot review instructions

Follow `AGENTS.md` at the repository root for project overview, commands and conventions. Review only against the points below; skip generic advice.

## Language

Deliverables (comments, docs, commit messages, PR text) are English. `README-ja.md` is an intentional Japanese translation that must stay in sync with `README.md`. Runtime messages are English without emoji.

## Checklist

- POSIX `sh` only: flag bashisms (`[[ ]]`, `local`, arrays, `function`, `$'...'`) and anything `shellcheck mkwork.sh` would report (unquoted expansions, unchecked `cd`).
- Internal functions use the `mkwork__` prefix. Flag new global variables that could clobber the user's shell environment, since the script is sourced.
- Errors print to stderr and `return 1`; flag any `exit`. Flag swallowed `curl`, `jq` or checksum failures in install and update commands (the background update check is intentionally silent), and any dependency of the core create-and-`cd` path on them.
- Downloaded release assets must be verified with `mkwork__sha256_check`. Flag unquoted or unvalidated user input that reaches files, URLs or `rm`.
- User-facing changes need updates to both READMEs and a case in `.github/workflows/smoke-test.yml`.

## Do not flag

- The absence of a test framework (ShellCheck plus smoke tests is the policy).
- POSIX-only style where Bash would be shorter.
- The `MKWORK_VERSION` value (replaced by the release workflow).
