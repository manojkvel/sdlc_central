#!/bin/bash
# Supported-surface helpers for the installers. Reads registry/support.yaml (bracket lists, may span lines).
# EXPERIMENTAL=1 (from --experimental or ATTICUS_EXPERIMENTAL=1) installs everything, as before the freeze.

# support_list <root> <section> <key>  → one item per line
support_list() {
  awk -v sec="$2:" -v key="$3:" '
    $0 ~ "^" sec { s=1; next }
    s && /^[a-z_]+:/ { s=0 }
    s && index($0, key) && !grab { grab=1; sub(".*" key "[ ]*\\[", "") }
    grab { line=$0; sub(/#.*/, "", line); out = out " " line; if (line ~ /\]/) { grab=0; s=0 } }
    END { gsub(/[][,]/, " ", out); n=split(out, a, " "); for (i=1;i<=n;i++) if (a[i]!="") print a[i] }
  ' "$1/registry/support.yaml"
}

support_has() { support_list "$1" "$2" "$3" | grep -qx "$4"; }

# Refuse an experimental agent unless EXPERIMENTAL=1. Exit code 3 so callers can tell it apart.
support_check_agent() {
  local root="$1" agent="$2"
  [ "${EXPERIMENTAL:-0}" = 1 ] && return 0
  support_has "$root" agents supported "$agent" && return 0
  echo "Agent '$agent' is experimental in this release (frozen: kept, not developed, not in the default install)." >&2
  echo "Use --agent claude-code (enforcing) or --agent agents-md (advisory, enforced in CI), or add --experimental." >&2
  exit 3
}
