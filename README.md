# op_secret_path: direnv + 1Password session-scoped file helper

`op_secret_path.sh` provides the `op_secret_path` function so direnv can fetch a 1Password secret into a temp file (for tools that require file paths, like private keys), keep it alive for the lifetime of your shell tab, and clean it up safely.

Inspired by the excellent [`direnv-1password`](https://github.com/tmatilai/direnv-1password/) project.

## Why you might want this

- Your tool needs a file, not an env var (SSH keys, Snowflake keys, certs).
- direnv runs in a subshell; naive cleanup either deletes the file immediately or loses track of it.
- You want per-tab isolation and automatic cleanup when the tab exits.

## Quick examples

In a project `.envrc`:

```sh
# Snowflake key as a file, passphrase as string
op_secret_path SNOWFLAKE_PRIVATE_KEY="op://Employee/SnowFlake/private key"
from_op     SNOWFLAKE_PRIVATE_KEY_PASSWORD="op://Employee/SnowFlake/password"
export PRIVATE_KEY_PASSPHRASE="$SNOWFLAKE_PRIVATE_KEY_PASSWORD"
```

SSH deploy key:

```sh
op_secret_path DEPLOY_SSH_KEY="op://Work/DeployKey/private key"
export GIT_SSH_COMMAND="ssh -i $DEPLOY_SSH_KEY -o IdentitiesOnly=yes"
```

Note: `from_op` is provided by the upstream [`direnv-1password`](https://github.com/tmatilai/direnv-1password/) project.

## Requirements

- direnv (v2.x)
- 1Password CLI (`op`) installed and signed in (`op account get` should work)
- POSIX shell (script uses `set -euo pipefail`)

## Install / load

### Local (repo checkout)

```sh
# ~/.config/direnv/direnvrc
source "path/to/OP_PATH/op_secret_path.sh"
```

### Remote (recommended)

Use `source_url` in your `~/.config/direnv/direnvrc`:

```sh
# Replace <org> and <tag> with actual values, e.g.:
# source_url "https://github.com/yourusername/OP_PATH/raw/v1.0.0/op_secret_path.sh" "sha256-<checksum>"
source_url "https://github.com/<org>/OP_PATH/raw/<tag>/op_secret_path.sh" "sha256-<pinned-sha256>"
```

**Getting the checksum:**

1. Check the [GitHub Releases](https://github.com/<org>/OP_PATH/releases) page for the version you want
2. The release notes include the SHA256 checksum in direnv format (`sha256-...`)
3. Or compute it yourself:
   ```sh
   direnv fetchurl "https://github.com/<org>/OP_PATH/raw/<tag>/op_secret_path.sh"
   ```

## How it works

- Runs `op read` to fetch the item.
- Writes to `${TMPDIR:-/tmp}` (or `/dev/shm` on Linux) as `direnv-<sha256>-<PID>.secret`.
- Sets permissions to `0600`.
- GC: removes `direnv-*-*.secret` files whose PIDs are no longer running.
- Per-PID idempotency: reuses the same file for the current shell PID if present.

## Cleanup

- Recommended: keep a `zshexit` (or equivalent) hook that deletes `direnv-*-<PID>.secret` for the current shell PID. Example (zsh):

```sh
_op_path_session_cleanup() {
  emulate -L zsh
  setopt local_options null_glob
  local tmp_root="${TMPDIR:-/tmp}"
  local file
  for file in "${tmp_root}"/direnv-*-$$.secret(N); do
    rm -P "$file" 2>/dev/null || rm -f "$file"
  done
}
autoload -Uz add-zsh-hook
add-zsh-hook zshexit _op_path_session_cleanup
```

## Security notes

- Files are `0600`; no group/world access.
- Uses `/dev/shm` on Linux to prefer RAM; macOS uses `$TMPDIR`.
- Exports only file paths; contents stay on disk until cleaned.
