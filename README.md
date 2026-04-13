# op_secret_path: mise + 1Password session-scoped file helper

`op_secret_path.sh` provides the `op_secret_path` function so mise can fetch a 1Password secret into a temp file (for tools that require file paths, like private keys), keep it alive for the lifetime of your shell tab, and clean it up safely.

Inspired by the excellent [`direnv-1password`](https://github.com/tmatilai/direnv-1password/) project.

## Why you might want this

- Your tool needs a file, not an env var (SSH keys, Snowflake keys, certs).
- You want per-tab isolation and automatic cleanup when the tab exits.

## Quick examples

In a project `env.sh` sourced by mise:

```sh
# Snowflake key as a file, passphrase as env var
op_secret_path SNOWFLAKE_PRIVATE_KEY="op://Employee/SnowFlake/private key"
export SNOWFLAKE_PRIVATE_KEY_PASSWORD="$(op read "op://Employee/SnowFlake/password")"
export PRIVATE_KEY_PASSPHRASE="$SNOWFLAKE_PRIVATE_KEY_PASSWORD"
```

SSH deploy key:

```sh
op_secret_path DEPLOY_SSH_KEY="op://Work/DeployKey/private key"
export GIT_SSH_COMMAND="ssh -i $DEPLOY_SSH_KEY -o IdentitiesOnly=yes"
```

## Requirements

- [mise](https://mise.jdx.dev/) (any recent version)
- 1Password CLI (`op`) installed and signed in (`op account get` should work)
- POSIX shell

## Install / load

### Option 1: Source in your shell profile

Download the script and source it in `~/.zshrc` (or equivalent):

```sh
source "path/to/op_secret_path.sh"
```

### Option 2: Download from releases

Check the [GitHub Releases](https://github.com/priiiiit/mise-1password-file-path/releases) page for the latest version and SHA256 checksum.

## Usage with mise

Create an `env.sh` in your project that calls `op_secret_path`, then tell mise to source it:

**`mise.toml`:**

```toml
[env]
_.source = ["env.sh"]
```

**`env.sh`:**

```sh
op_secret_path SNOWFLAKE_PRIVATE_KEY="op://Employee/SnowFlake/private key"
```

When you `cd` into the project directory, mise will source `env.sh`, which calls `op_secret_path` to fetch the secret into a temp file and export the path.

## How it works

- Runs `op read` to fetch the item.
- Writes to `${TMPDIR:-/tmp}` (or `/dev/shm` on Linux) as `op-secret-<sha256>-<PID>.secret`.
- Sets permissions to `0600`.
- GC: removes `op-secret-*-*.secret` files whose PIDs are no longer running.
- Per-PID idempotency: reuses the same file for the current shell PID if present.
- PID detection: walks up the process tree from the subprocess to find the interactive shell PID, ensuring the secret file is tied to the tab's lifetime rather than a transient mise subprocess.

## Advanced: manual PID override

If auto-detection picks the wrong PID (unusual container or nesting setup), set `OP_SECRET_SHELL_PID` before mise activates:

```sh
export OP_SECRET_SHELL_PID=$$
```

## Cleanup

Recommended: keep a `zshexit` (or equivalent) hook that deletes `op-secret-*-<PID>.secret` for the current shell PID. Example (zsh):

```sh
_op_path_session_cleanup() {
  emulate -L zsh
  setopt local_options null_glob
  local tmp_root="${TMPDIR:-/tmp}"
  local file
  for file in "${tmp_root}"/op-secret-*-$$.secret(N); do
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
