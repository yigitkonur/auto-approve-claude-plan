#!/bin/bash
set -euo pipefail

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claude-plan-hook.sh"

if [ -t 1 ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BOLD='\033[1m'
  DIM='\033[2m'
else
  GREEN=''
  YELLOW=''
  BOLD=''
  DIM=''
fi
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

if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  if jq -e '
    (.hooks.PermissionRequest[]? | select(.matcher == "ExitPlanMode"))
    , (.hooks.PostToolUse[]? | select(.matcher == "ExitPlanMode"))
  ' "$SETTINGS" &>/dev/null; then
    TMP=$(mktemp)
    trap 'rm -f "${TMP:-}"' EXIT

    if ! jq '
      .hooks.PermissionRequest = [
        .hooks.PermissionRequest[]? |
        select(.matcher != "ExitPlanMode")
      ] |
      if .hooks.PermissionRequest == [] then del(.hooks.PermissionRequest) else . end |
      .hooks.PostToolUse = [
        .hooks.PostToolUse[]? |
        select(.matcher != "ExitPlanMode")
      ] |
      if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |
      if .hooks == {} then del(.hooks) else . end
    ' "$SETTINGS" > "$TMP" 2>/dev/null; then
      warn "jq failed — settings.json not modified."
      rm -f "$TMP"
      exit 1
    fi

    if ! jq empty "$TMP" 2>/dev/null; then
      warn "jq produced invalid JSON — settings.json not modified."
      rm -f "$TMP"
      exit 1
    fi

    mv "$TMP" "$SETTINGS"
    ok "Removed hook entries from ${SETTINGS}"
  else
    info "No hook entries found in settings.json"
  fi
else
  if [ ! -f "$SETTINGS" ]; then
    info "No settings.json found"
  else
    warn "jq not found — ${SETTINGS} must be manually edited."
    printf "\n${DIM}To remove the hook entry, find this block in ${SETTINGS}:${NC}\n"
    cat <<'JSONSNIP'
  "PermissionRequest": [
    {
      "matcher": "ExitPlanMode",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/claude-plan-hook.sh"
        }
      ]
    }
  ]
JSONSNIP
    printf "\n${DIM}and delete it, then save the file.${NC}\n\n"
  fi
fi

printf "\n${GREEN}${BOLD}Uninstalled.${NC}\n"
printf "  ${DIM}Restart Claude Code for changes to take effect.${NC}\n\n"
