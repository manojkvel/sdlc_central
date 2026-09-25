#!/bin/bash
# Atticus bootstrap: clone (or update) the framework, then run `atticus setup` (PATH, shell profile, completion).
#   curl -fsSL https://raw.githubusercontent.com/manojkvel/sdlc_central/main/get-atticus.sh | bash
# Environment:
#   ATTICUS_HOME  where the framework lives   (default ~/.atticus)
#   ATTICUS_REF   branch or tag to check out   (default main)
#   ATTICUS_REPO  git URL                      (default https://github.com/manojkvel/sdlc_central.git)
#   ATTICUS_BIN   directory for the command    (default ~/.local/bin)
set -e
HOME_DIR="${ATTICUS_HOME:-$HOME/.atticus}"
REF="${ATTICUS_REF:-main}"
REPO="${ATTICUS_REPO:-https://github.com/manojkvel/sdlc_central.git}"
BIN="${ATTICUS_BIN:-$HOME/.local/bin}"
command -v git >/dev/null 2>&1 || { echo "atticus: git is required" >&2; exit 1; }
if [ -d "$HOME_DIR/.git" ]; then
  git -C "$HOME_DIR" fetch --quiet origin "$REF"
  git -C "$HOME_DIR" checkout --quiet "$REF"
  git -C "$HOME_DIR" pull --quiet --ff-only origin "$REF" || true
else
  git clone --quiet --branch "$REF" "$REPO" "$HOME_DIR"
fi
ATTICUS_BIN="$BIN" bash "$HOME_DIR/bin/atticus" setup
command -v jq >/dev/null 2>&1 || echo "atticus: install jq before use (brew install jq | sudo apt-get install jq | winget install jqlang.jq)"
echo "Then, in a project:  atticus init"
