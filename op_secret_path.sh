#!/bin/sh
# op_secret_path: session-scoped 1Password file helper for direnv
# POSIX-friendly so it can be fetched with direnv's source_url.

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

  # Identify the interactive shell PID. direnv runs in a subshell, so use the parent.
  parent_from_ps="$(ps -o ppid= -p $$ 2>/dev/null | tr -d '[:space:]')"
  shell_pid="${DIRENV_PARENT_PID:-${parent_from_ps:-$PPID}}"

  # Prefer RAM disk on Linux when available; macOS defaults to TMPDIR.
  tmp_root="${TMPDIR:-/tmp}"
  if [ "$(uname -s)" != "Darwin" ] && [ -d /dev/shm ]; then
    tmp_root="/dev/shm"
  fi

  hash="$(printf '%s' "${op_ref}" | shasum -a 256 | cut -d' ' -f1)"
  filepath="${tmp_root}/direnv-${hash}-${shell_pid}.secret"

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
  for file in "${root}"/direnv-*-*.secret; do
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
