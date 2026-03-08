#!/bin/bash
set -euo pipefail

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claude-plan-hook.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()   { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[!!]${NC} %s\n" "$1"; }
info() { printf "${DIM}[..]${NC} %s\n" "$1"; }

printf "\n${BOLD}  claude-plan-hook uninstaller${NC}\n\n"

if [ -f "$HOOK_SCRIPT" ]; then
  rm -f "$HOOK_SCRIPT"
  ok "Removed ${HOOK_SCRIPT}"
else
  info "Hook script not found (already removed)"
fi

rm -f "$HOOK_DIR/craft-config.env" 2>/dev/null

if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  if jq -e '.hooks.PermissionRequest[]? | select(.matcher == "ExitPlanMode")' "$SETTINGS" &>/dev/null; then
    TMP=$(mktemp)
    jq '
      .hooks.PermissionRequest = [
        .hooks.PermissionRequest[]? |
        select(.matcher != "ExitPlanMode")
      ] |
      if .hooks.PermissionRequest == [] then del(.hooks.PermissionRequest) else . end |
      if .hooks == {} then del(.hooks) else . end
    ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
    ok "Removed hook entry from ${SETTINGS}"
  else
    info "No hook entry found in settings.json"
  fi
else
  if [ ! -f "$SETTINGS" ]; then
    info "No settings.json found"
  else
    warn "jq not found — manually remove ExitPlanMode entry from ${SETTINGS}"
  fi
fi

printf "\n${GREEN}${BOLD}Uninstalled.${NC}\n"
printf "  ${DIM}Restart Claude Code for changes to take effect.${NC}\n\n"
