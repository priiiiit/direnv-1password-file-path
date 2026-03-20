#!/bin/sh
# op_secret_path: session-scoped 1Password file helper for direnv
# POSIX-friendly so it can be fetched with direnv's source_url.
#
# SETUP: See README.md for complete installation instructions.
# This file provides the op_secret_path and op_secret_path_encrypted functions for direnv.
# For automatic cleanup, also source op_secret_path_cleanup.zsh in your .zshrc

# Internal helper: parse arguments, resolve paths, build filepath.
# Sets: _osp_var_name, _osp_op_ref, _osp_filepath
_op_secret_path_core() {
  _osp_fn_name="$1"
  _osp_prefix="$2"
  shift 2

  # Accept KEY=OP_REF and keep KEY OP_REF fallback.
  raw="${1-}"
  _osp_op_ref="${2-}"
  if [ "${raw#*=}" != "${raw}" ]; then
    _osp_var_name="${raw%%=*}"
    _osp_op_ref="${raw#*=}"
  else
    _osp_var_name="${raw}"
  fi

  if [ -z "${_osp_var_name:-}" ] || [ -z "${_osp_op_ref:-}" ]; then
    printf 'Usage: %s VAR_NAME=op://vault/item/field\n' "${_osp_fn_name}" >&2
    printf '   or: %s VAR_NAME "op://vault/item/field"\n' "${_osp_fn_name}" >&2
    return 1
  fi
  if ! command -v op >/dev/null 2>&1; then
    printf 'op CLI not found in PATH\n' >&2
    return 1
  fi

  # Session ID from interactive shell (set by op_secret_path_cleanup.zsh)
  # This MUST be set for cleanup to work correctly
  if [ -z "${OP_SECRET_SESSION_ID:-}" ]; then
    printf 'Warning: OP_SECRET_SESSION_ID not set. Cleanup will not work.\n' >&2
    printf 'Source op_secret_path_cleanup.zsh in your .zshrc\n' >&2
    _osp_shell_pid="$$"
  else
    _osp_shell_pid="${OP_SECRET_SESSION_ID}"
  fi

  # Prefer RAM disk on Linux; macOS uses TMPDIR
  _osp_tmp_root="${TMPDIR:-/tmp}"
  if [ "$(uname -s)" != "Darwin" ] && [ -d /dev/shm ]; then
    _osp_tmp_root="/dev/shm"
  fi

  # Hash of direnv directory for per-directory cleanup (canonical path to avoid symlink mismatches)
  _osp_dir_hash="none"
  if [ -n "${DIRENV_DIR:-}" ]; then
    if _osp_dir_real="$(cd "${DIRENV_DIR}" 2>/dev/null && pwd -P)"; then
      _osp_dir_hash="$(printf '%s' "${_osp_dir_real}" | shasum -a 256 | cut -c1-8)"
    else
      _osp_dir_hash="$(printf '%s' "${DIRENV_DIR}" | shasum -a 256 | cut -c1-8)"
    fi
  fi

  _osp_ref_hash="$(printf '%s' "${_osp_op_ref}" | shasum -a 256 | cut -d' ' -f1)"
  _osp_filepath="${_osp_tmp_root}/direnv-${_osp_prefix}${_osp_ref_hash}-${_osp_dir_hash}-${_osp_shell_pid}.secret"
}

op_secret_path() {
  set -eu

  _op_secret_path_core "op_secret_path" "" "$@"

  if [ ! -f "${_osp_filepath}" ]; then
    if ! op read "${_osp_op_ref}" > "${_osp_filepath}"; then
      rm -f "${_osp_filepath}"
      printf 'op read failed for %s\n' "${_osp_op_ref}" >&2
      return 1
    fi
    chmod 600 "${_osp_filepath}" || {
      rm -f "${_osp_filepath}"
      printf 'chmod failed for %s\n' "${_osp_filepath}" >&2
      return 1
    }
  fi

  export "${_osp_var_name}"="${_osp_filepath}"
}

# Fetch a private key from 1Password, re-encrypt it with a random passphrase,
# and export both the file path and the passphrase as environment variables.
# The plaintext key never touches disk — it is piped directly through openssl.
op_secret_path_encrypted() {
  set -eu

  if ! command -v openssl >/dev/null 2>&1; then
    printf 'openssl required for op_secret_path_encrypted\n' >&2
    return 1
  fi

  _op_secret_path_core "op_secret_path_encrypted" "enc-" "$@"

  # No caching: passphrase must be generated fresh each time direnv evaluates.
  # Remove stale file from a previous load if present.
  rm -f "${_osp_filepath}"

  _osp_passphrase="$(openssl rand -base64 32)"

  # Pipe op read directly into openssl — plaintext never touches disk.
  if ! op read "${_osp_op_ref}" \
    | openssl pkey -aes256 -passout "pass:${_osp_passphrase}" -out "${_osp_filepath}" 2>/dev/null; then
    rm -f "${_osp_filepath}"
    printf 'Encryption failed for %s. Is this a valid private key?\n' "${_osp_op_ref}" >&2
    return 1
  fi

  chmod 600 "${_osp_filepath}" || {
    rm -f "${_osp_filepath}"
    printf 'chmod failed for %s\n' "${_osp_filepath}" >&2
    return 1
  }

  export "${_osp_var_name}"="${_osp_filepath}"
  export "${_osp_var_name}_PASSPHRASE"="${_osp_passphrase}"
}
