#!/bin/sh
# op_secret_path: session-scoped 1Password file helper for mise
# Source this file via mise's env._source or from your shell profile.

_op_secret_find_shell_pid() {
  # Walk ancestors until we find a shell process — that's the interactive shell.
  # mise's env._source runs scripts in a bash subprocess, so $$ and $PPID are
  # transient PIDs. We need the long-lived interactive shell PID for per-tab
  # isolation and GC.
  pid="$PPID"
  while [ -n "${pid}" ] && [ "${pid}" != "1" ] && [ "${pid}" != "0" ]; do
    comm="$(ps -o comm= -p "${pid}" 2>/dev/null | tr -d '[:space:]')"
    case "${comm}" in
      zsh|-zsh|bash|-bash|fish|dash|sh|-sh|ksh|-ksh)
        printf '%s' "${pid}"
        return
        ;;
    esac
    pid="$(ps -o ppid= -p "${pid}" 2>/dev/null | tr -d '[:space:]')"
  done
  printf '%s' "${PPID:-$$}"
}

op_secret_path() {
  # POSIX sh: no pipefail; -e/-u still enforced
  set -eu

  # Accept KEY=OP_REF and keep KEY OP_REF fallback.
  raw="${1-}"
  op_ref="${2-}"
  if [ "${raw#*=}" != "${raw}" ]; then
    var_name="${raw%%=*}"
    op_ref="${raw#*=}"
  else
    var_name="${raw}"
  fi

  if [ -z "${var_name:-}" ] || [ -z "${op_ref:-}" ]; then
    printf 'Usage: op_secret_path VAR_NAME=op://vault/item/field\n' >&2
    printf '   or: op_secret_path VAR_NAME "op://vault/item/field"\n' >&2
    return 1
  fi
  if ! command -v op >/dev/null 2>&1; then
    printf 'op CLI not found in PATH\n' >&2
    return 1
  fi

  # Identify the interactive shell PID. OP_SECRET_SHELL_PID allows manual override.
  shell_pid="${OP_SECRET_SHELL_PID:-$(_op_secret_find_shell_pid)}"

  # Prefer RAM disk on Linux when available; macOS defaults to TMPDIR.
  tmp_root="${TMPDIR:-/tmp}"
  if [ "$(uname -s)" != "Darwin" ] && [ -d /dev/shm ]; then
    tmp_root="/dev/shm"
  fi

  hash="$(printf '%s' "${op_ref}" | shasum -a 256 | cut -d' ' -f1)"
  filepath="${tmp_root}/op-secret-${hash}-${shell_pid}.secret"

  _op_secret_path_gc "${tmp_root}"

  if [ ! -f "${filepath}" ]; then
    if ! op read "${op_ref}" > "${filepath}"; then
      rm -f "${filepath}"
      printf 'op read failed for %s\n' "${op_ref}" >&2
      return 1
    fi
    if ! chmod 600 "${filepath}"; then
      rm -f "${filepath}"
      printf 'chmod failed for %s\n' "${filepath}" >&2
      return 1
    fi
  fi

  export "${var_name}"="${filepath}"
}

_op_secret_path_gc() {
  root="${1:-${TMPDIR:-/tmp}}"
  for file in "${root}"/op-secret-*-*.secret; do
    [ -e "${file}" ] || continue
    base="$(basename -- "${file}")"
    pid_part="${base%.secret}"
    pid="${pid_part##*-}"
    case "${pid}" in
      (*[!0-9]*|'') continue ;;
    esac
    if ! kill -0 "${pid}" 2>/dev/null; then
      rm -P "${file}" 2>/dev/null || rm -f "${file}"
    fi
  done
}
