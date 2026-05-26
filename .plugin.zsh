export OP_SECRET_PATH_SCRIPT="${0:A:h}/op_secret_path.sh"
source "${0:A:h}/op_secret_path.sh"

# Pin the "owning shell" to this interactive zsh, so when mise spawns a bash
# subprocess to source env.sh, the helper attributes the temp file to this
# long-lived shell rather than the transient bash (which would be GC'd
# immediately on the next pass).
export OP_SECRET_SHELL_PID=$$

# Remove this shell's op-secret files on exit. Cross-shell stragglers are
# cleaned up by op_secret_path's GC on the next call from any shell.
_op_secret_path_session_cleanup() {
  emulate -L zsh
  setopt local_options null_glob
  local tmp_root="${TMPDIR:-/tmp}"
  local file
  for file in "${tmp_root}"/op-secret-*-$$.secret(N); do
    rm -P "$file" 2>/dev/null || rm -f "$file"
  done
}
autoload -Uz add-zsh-hook
add-zsh-hook zshexit _op_secret_path_session_cleanup
