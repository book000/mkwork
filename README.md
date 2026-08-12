# mkwork

mkwork is a shell-function utility that creates a dated work directory and moves into it immediately.

- Automatically creates `~/work/YYYYMMDD_name`
- Changes directory to the newly created path
- Available in the current shell right after install
- Self-update and uninstall are done via `mkwork` itself (standalone install only; see "Install via mise")

## Dependencies

The following are required for update checks, updates, and release downloads:

- `curl`
- `jq`
- `sha256sum` or `shasum`

## Install

```sh
. <(curl -fsSL https://github.com/book000/mkwork/releases/latest/download/mkwork.sh)
mkwork --install
```

mkwork will append its rc block to one of the following:

- bash: `~/.bashrc`
- zsh: `~/.zshrc`
- others: `~/.profile`

## Install via mise

mkwork can also be installed and run through [mise](https://mise.jdx.dev/), using the same release asset as the standalone installer. Add the following to your `mise.toml`:

```toml
[tools]
"github:book000/mkwork" = { version = "<version>", asset_pattern = "mkwork.sh", bin = "mkwork.sh" }

[shell_alias]
mkwork = '''
unalias mkwork
export MKWORK_INSTALL_METHOD=mise
. "$(mise where github:book000/mkwork)/mkwork.sh"
unset MKWORK_INSTALL_METHOD
mkwork
'''
```

`unalias mkwork` is required: Bash expands the `mkwork` alias while reading the `mkwork() { ... }` function definition inside `mkwork.sh`, which would otherwise cause a syntax error.

When installed this way, mkwork detects it is mise-managed and disables its own `--install`, `--update`, `--uninstall`, and periodic update checks — use mise itself to upgrade or remove it (`mise upgrade` / `mise uninstall github:book000/mkwork`). `mkwork <name>`, `mkwork --select`, `mkwork --doctor`, and `mkwork --version` keep working as usual. `mkwork --doctor` reports which mode is active via a `managed_by: mise|standalone` line.

## Usage

```sh
mkwork example
```

This creates and moves into `~/work/20260106_example`.

## Error Handling

- Unknown options (anything starting with `-` that mkwork does not recognize) cause an error; mkwork exits with status 1 and prints the error to stderr.
- Work names starting with `-` are not allowed (they are treated as unknown options).
- `--` is not supported as an option terminator; it is treated as an unknown option like any other unrecognized `-`-prefixed argument.
- `mkwork --install --repo` requires a value; omitting it is an error.
- `version` and `help` are reserved dispatch words and cannot be used as work names.

## Select a Directory

```sh
mkwork --select
```

This lists existing work directories under `work_root` and moves into the selected one.
If `fzf` is installed, it uses an interactive fuzzy finder; otherwise it falls back to a number-input prompt.

## Management Commands

```sh
mkwork --install
mkwork --update
mkwork --uninstall
mkwork --doctor
mkwork --version
```

## Configuration

Configuration is file-based. The only exception is `MKWORK_INSTALL_METHOD`, which the mise `[shell_alias]` bootstrap uses transiently (see "Install via mise" above) and which mkwork unsets after reading it.

Load order (later wins):

1. `~/.config/mkwork/config`
2. `/etc/mkwork/config`

Format:

- POSIX shell compatible
- `KEY=VALUE`
- Unknown keys are ignored

Options:

- `repo=OWNER/REPO` (update source)
- `work_root=~/work`
- `update_check=0|1` (default 1)
- `notify_update=0|1` (default 1)
- `auto_update=0|1` (default 0)
- `update_check_interval_days=1`

### Override repo during install

```sh
mkwork --install --repo OWNER/REPO
```

Do not persist the override:

```sh
mkwork --install --repo OWNER/REPO --write-config=none
```

## Update checks

mkwork checks for updates once per day when you run it.

- Only when `update_check=1`
- Checks if `update_check_interval_days` has elapsed
- Notifies only when an update is found (`notify_update=1`)
- Auto-update runs only with `auto_update=1`
- Failures do not block core mkwork functionality

State is stored at:

- Non-root: `~/.local/state/mkwork/state.json`
- Root: `/var/lib/mkwork/state.json`

## Uninstall

```sh
mkwork --uninstall
```

This removes the rc block, installed script, config, and state.
Not available when mise-managed; see "Install via mise" for cleanup in that case.

## Why a shell function?

mkwork runs as a shell function so it can `mkdir + cd` in the parent shell.
