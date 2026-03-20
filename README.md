# op_secret_path: direnv + 1Password session-scoped file helper

Fetch 1Password secrets into temporary files for tools that require file paths (SSH keys, Snowflake keys, certificates). Files are automatically cleaned up when you leave the directory or close your terminal.

Inspired by [`direnv-1password`](https://github.com/tmatilai/direnv-1password/).

## Why you need this

- Your tool needs a **file path**, not an environment variable
- direnv runs in a subshell — naive cleanup breaks the workflow
- You want **automatic cleanup** when leaving the directory (security)

## Installation (Two Files Required)

⚠️ **Both files must be sourced for automatic cleanup to work.**

Due to how direnv works (isolated subprocess), cleanup hooks must run in your interactive shell. This requires two source statements.

### Step 1: Source cleanup hooks in `~/.zshrc`

```zsh
# Add BEFORE the direnv hook (eval "$(direnv hook zsh)")
source "path/to/op_secret_path_cleanup.zsh"
```

Or with `source_url` (after first release):
```zsh
# Download once, then source locally
curl -o ~/.config/direnv/op_secret_path_cleanup.zsh \
  "https://github.com/<org>/direnv-1password-file-path/raw/<tag>/op_secret_path_cleanup.zsh"
source ~/.config/direnv/op_secret_path_cleanup.zsh
```

### Step 2: Source function in `~/.config/direnv/direnvrc`

```sh
# Local
source "path/to/op_secret_path.sh"

# Or remote with source_url
source_url "https://github.com/<org>/direnv-1password-file-path/raw/<tag>/op_secret_path.sh" "sha256-<checksum>"
```

### Getting the checksum

Check the [Releases](https://github.com/priiiiit/direnv-1password-file-path/releases) page, or compute it:
```sh
direnv fetchurl "https://github.com/<org>/direnv-1password-file-path/raw/<tag>/op_secret_path.sh"
```

## Usage

In your project's `.envrc`:

```sh
# Snowflake private key as a file
op_secret_path SNOWFLAKE_PRIVATE_KEY="op://Employee/SnowFlake/private key"

# SSH deploy key
op_secret_path DEPLOY_SSH_KEY="op://Work/DeployKey/private key"
export GIT_SSH_COMMAND="ssh -i $DEPLOY_SSH_KEY -o IdentitiesOnly=yes"
```

### Encrypted keys (recommended for private keys)

`op_secret_path_encrypted` re-encrypts the key with a random passphrase before writing it to disk. The plaintext key never touches the filesystem — it is piped directly through `openssl`.

```sh
# Snowflake private key — encrypted at rest
op_secret_path_encrypted SNOWFLAKE_KEY="op://Employee/SnowFlake/private key"
# Exports:
#   SNOWFLAKE_KEY           → path to encrypted PEM file
#   SNOWFLAKE_KEY_PASSPHRASE → random passphrase to decrypt it

# SSH deploy key — encrypted at rest
op_secret_path_encrypted DEPLOY_SSH_KEY="op://Work/DeployKey/private key"
export GIT_SSH_COMMAND="ssh -i $DEPLOY_SSH_KEY -o IdentitiesOnly=yes"
```

Consuming tools use the companion `_PASSPHRASE` variable:
- **SSH**: prompts for passphrase automatically, or use `ssh-agent`
- **Snowflake**: set `private_key_passphrase` in your connector config to `$SNOWFLAKE_KEY_PASSPHRASE`

## How it works

### `op_secret_path`

1. Fetches the secret via `op read`
2. Writes to a temp file: `direnv-<hash>-<dir_hash>-<session_id>.secret`
3. Sets permissions to `0600` (owner read/write only)
4. Exports the file path as the specified variable

### `op_secret_path_encrypted`

1. Generates a random passphrase via `openssl rand -base64 32`
2. Pipes `op read` directly into `openssl pkey -aes256` — plaintext never touches disk
3. Writes the encrypted PEM to: `direnv-enc-<hash>-<dir_hash>-<session_id>.secret`
4. Sets permissions to `0600`
5. Exports the file path as the specified variable, and the passphrase as `${VAR_NAME}_PASSPHRASE`

**Cleanup behavior:**
- **Leave directory** → file deleted immediately (via `chpwd` hook)
- **Close terminal** → file deleted (via `zshexit` hook)
- **Crash/kill** → file cleaned up on next terminal open (when hooks load)

## Requirements

- direnv (v2.x)
- 1Password CLI (`op`) — signed in (`op account get` should work)
- Zsh (for automatic cleanup hooks)
- OpenSSL or LibreSSL (only for `op_secret_path_encrypted`)

## Security

| Protection | Details |
|------------|---------|
| File permissions | `0600` — only you can read |
| Linux storage | `/dev/shm` (RAM disk) — never touches disk |
| macOS storage | `$TMPDIR` — on SSD but FileVault encrypts |
| Secure delete | `rm -P` used where available (overwrites before delete) |
| Isolation | Each terminal session has its own files |
| Encryption at rest | `op_secret_path_encrypted` re-encrypts keys with a random passphrase; plaintext never written to disk |

## Files

| File | Purpose | Where to source |
|------|---------|-----------------|
| `op_secret_path.sh` | POSIX function for direnv | `~/.config/direnv/direnvrc` |
| `op_secret_path_cleanup.zsh` | Zsh cleanup hooks | `~/.zshrc` (before direnv hook) |

## Why two files?

direnv evaluates `.envrc` in an **isolated subprocess** (bash). That subprocess cannot register hooks in your interactive shell (zsh). Therefore:

1. The **function** must be available in direnv's context → `direnvrc`
2. The **cleanup hooks** must run in your shell → `.zshrc`

This is a fundamental limitation of how direnv works, not a design choice.
