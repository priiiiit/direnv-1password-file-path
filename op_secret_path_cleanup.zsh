#!/bin/zsh
# op_secret_path_cleanup.zsh: Cleanup hooks for op_secret_path
#
# SOURCE THIS FILE IN YOUR .zshrc (before direnv hook):
#   source "path/to/op_secret_path_cleanup.zsh"
#
# This file:
# 1. Exports OP_SECRET_SESSION_ID so op_secret_path can create correctly-named files
# 2. Registers hooks to clean up secret files when you leave a directory or close the shell

# Export session ID - this is inherited by direnv subshells
export OP_SECRET_SESSION_ID="$$"

# Cleanup when leaving a direnv-managed directory
_op_secret_path_chpwd_cleanup() {
  emulate -L zsh
  setopt local_options null_glob
  local tmp_root="${TMPDIR:-/tmp}"
  local direnv_dir="${DIRENV_DIR:-}"
  local dir_hash="none"

  # chpwd runs BEFORE direnv unloads, so DIRENV_DIR is still set
  # Check if we've left the direnv directory tree
  if [[ -n "$direnv_dir" && "$PWD" != "$direnv_dir" && "$PWD" != "$direnv_dir"/* ]]; then
    # Use canonical path to avoid symlink mismatches between direnv and shell PWD
    if dir_real=$(cd "$direnv_dir" 2>/dev/null && pwd -P); then
      dir_hash=$(printf '%s' "$dir_real" | shasum -a 256 | cut -c1-8)
    else
      dir_hash=$(printf '%s' "$direnv_dir" | shasum -a 256 | cut -c1-8)
    fi
    local file
    for file in "${tmp_root}"/direnv-*-${dir_hash}-${OP_SECRET_SESSION_ID}.secret(N); do
      rm -P "$file" 2>/dev/null || rm -f "$file"
    done
  fi
}

# Cleanup ALL secret files for this shell on exit
_op_secret_path_zshexit_cleanup() {
  emulate -L zsh
  setopt local_options null_glob
  local tmp_root="${TMPDIR:-/tmp}"
  local file
  for file in "${tmp_root}"/direnv-*-${OP_SECRET_SESSION_ID}.secret(N); do
    rm -P "$file" 2>/dev/null || rm -f "$file"
  done
}

# Register hooks
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _op_secret_path_chpwd_cleanup
add-zsh-hook zshexit _op_secret_path_zshexit_cleanup
