# mkwork

mkwork is a shell-function utility that creates a dated work directory and moves into it immediately.

- Automatically creates `~/work/YYYYMMDD_name`
- Changes directory to the newly created path
- Available in the current shell right after install
- Self-update and uninstall are done via `mkwork` itself

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

## Usage

```sh
mkwork example
```

This creates and moves into `~/work/20260106_example`.

## Management Commands

```sh
mkwork --install
mkwork --update
mkwork --uninstall
mkwork --doctor
mkwork --version
```

## Configuration

Configuration is file-based only (no environment variables).

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

## Why a shell function?

mkwork runs as a shell function so it can `mkdir + cd` in the parent shell.
