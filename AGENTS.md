# AGENTS.md

Guidance for AI coding agents and contributors. `CLAUDE.md` imports this file, and `.github/copilot-instructions.md` adds the review checklist.

## Language

- All deliverables are written in **English**: commit messages, PR/Issue titles and bodies, review comments, code comments, and documentation (`README.md`, `AGENTS.md`, etc.).
- `README-ja.md` is an intentionally kept Japanese translation of `README.md`. Update both in the same change.
- Exceptions (keep as is): quotations, technical identifiers, generated files, and external source text.
- Runtime messages (usage text, errors) are English, without emoji.
- Do not rewrite Git history to change the language of past commits.

## Overview

`mkwork` is a single POSIX `sh` script (`mkwork.sh`) that defines the shell function `mkwork`. It creates `$work_root/YYYYMMDD_<name>` (default `~/work`) and `cd`s into it in the calling shell, which is why it must be a function and not an executable. It also provides `--select`, `--install`, `--update`, `--uninstall`, `--doctor`, `--version` and `--help`, plus a periodic update check against GitHub releases.

## Commands

There is no build step and no test framework. CI (`.github/workflows/`) runs these:

```sh
sh -n mkwork.sh        # syntax check
shellcheck mkwork.sh   # static analysis; must be clean
```

Basic smoke test (the first block of `smoke-test.yml`, which also covers install/uninstall, the mise scenario and error cases; always point `HOME` at a scratch directory because `--install` and `--uninstall` modify `$HOME`):

```sh
tmp_dir="$(mktemp -d)"
export HOME="$tmp_dir/home"
mkdir -p "$HOME"
. ./mkwork.sh
mkwork --version
mkwork --doctor
mkwork testdir
test -d "$HOME/work/$(date +%Y%m%d)_testdir"
```

`release.yml` runs when a release is published: it copies `mkwork.sh` to `dist/`, replaces the `MKWORK_VERSION="..."` line with the release tag, generates `mkwork.sh.sha256`, and uploads both as release assets. Do not bump `MKWORK_VERSION` by hand.

## Structure

- `mkwork.sh`: the whole implementation. Internal functions use the `mkwork__` prefix; configuration state uses `MKWORK_*` variables. The public entry point is `mkwork()` at the end of the file, which dispatches on the first argument.
- `README.md` / `README-ja.md`: user documentation (English / Japanese translation).
- `.github/workflows/`: `shellcheck.yml`, `smoke-test.yml`, `release.yml`.

Key behavior (verify in `mkwork.sh` before changing):

- Config files `~/.config/mkwork/config` then `/etc/mkwork/config` (later wins), `KEY=VALUE` lines, unknown keys ignored. Install, config and state paths depend on whether the user is root (`mkwork__install_paths`).
- The update check runs after `mkwork <name>` and `mkwork --select`, never blocks them, and is skipped when `curl`, `jq` or `sha256sum`/`shasum` is missing. Downloaded release assets are verified with `mkwork__sha256_check`.
- Setting `MKWORK_INSTALL_METHOD=mise` before sourcing marks the install as mise-managed: `--install`, `--update`, `--uninstall` and update checks are disabled. The variable is not exported.
- Unknown `-`-prefixed arguments are errors; `version` and `help` are reserved words.

## Conventions

- Stay POSIX `sh`: no bashisms (`[[ ]]`, `local`, arrays, `function`, `$'...'`). Quote every variable expansion.
- Prefix new functions with `mkwork__`. Because POSIX `sh` has no `local`, scratch variables in the existing functions are shared with the calling shell; do not reuse names of variables the user may have set.
- On failure, print a message to stderr and `return 1`. Never `exit`, because the script is sourced into the user's shell.
- The core feature (create directory and `cd`) must not depend on `curl`, `jq` or checksum tools; those are only for install, update and update checks.
- Validate user-controlled values that are written to files or used in URLs (see the `--repo` format check).
- Keep comments for intent and constraints; do not narrate what the code does.
- Update `README.md` and `README-ja.md` when commands, options, config keys or dependencies change, and add a matching case to `.github/workflows/smoke-test.yml` for user-facing behavior.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/); branches follow [Conventional Branch](https://conventional-branch.github.io) short form (`feat/...`, `fix/...`).
- Do not commit to Renovate PRs. Never commit secrets.
