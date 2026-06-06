#!/bin/bash
set -euo pipefail

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claude-plan-hook.sh"
DEEPEN_SCRIPT="$HOOK_DIR/plan-deepen.sh"

ALIAS_MARK_BEGIN="# >>> claude-plan-hook effort tiers >>>"
ALIAS_MARK_END="# <<< claude-plan-hook effort tiers <<<"

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

# ── Remove hook scripts ─────────────────────────────────────────────
if [ -f "$HOOK_SCRIPT" ]; then
  rm -f "$HOOK_SCRIPT"
  ok "Removed ${HOOK_SCRIPT}"
else
  info "Hook script not found (already removed)"
fi

if [ -f "$DEEPEN_SCRIPT" ]; then
  rm -f "$DEEPEN_SCRIPT"
  ok "Removed ${DEEPEN_SCRIPT}"
fi

# ── Strip hook entries from settings.json ───────────────────────────
# Removes our PermissionRequest/ExitPlanMode auto-approve entry, our
# UserPromptSubmit plan-deepen entry, and any legacy PostToolUse entry —
# all matched by command path so unrelated hooks are preserved.
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  TMP=$(mktemp)
  trap 'rm -f "${TMP:-}"' EXIT

  if ! jq '
    .hooks //= {} |
    # PermissionRequest: drop entries pointing at our auto-approve hook.
    ( if .hooks.PermissionRequest then
        .hooks.PermissionRequest = [
          .hooks.PermissionRequest[] |
          .hooks = [(.hooks // [])[] | select((.command // "") | test("auto-approve|claude-plan-hook"; "i") | not)] |
          select((.hooks // []) | length > 0)
        ] |
        ( if .hooks.PermissionRequest == [] then del(.hooks.PermissionRequest) else . end )
      else . end ) |
    # PostToolUse: drop legacy orchestrator entries.
    ( if .hooks.PostToolUse then
        .hooks.PostToolUse = [
          .hooks.PostToolUse[] |
          .hooks = [(.hooks // [])[] | select((.command // "") | test("auto-approve|claude-plan-hook"; "i") | not)] |
          select((.hooks // []) | length > 0)
        ] |
        ( if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end )
      else . end ) |
    # UserPromptSubmit: drop our plan-deepen entry, keep others.
    ( if .hooks.UserPromptSubmit then
        .hooks.UserPromptSubmit = [
          .hooks.UserPromptSubmit[] |
          .hooks = [(.hooks // [])[] | select((.command // "") | test("plan-deepen"; "i") | not)] |
          select((.hooks // []) | length > 0)
        ] |
        ( if .hooks.UserPromptSubmit == [] then del(.hooks.UserPromptSubmit) else . end )
      else . end ) |
    ( if .hooks == {} then del(.hooks) else . end )
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
  info "Left permissions.defaultMode and effortLevel untouched (your settings)."
else
  if [ ! -f "$SETTINGS" ]; then
    info "No settings.json found"
  else
    warn "jq not found — ${SETTINGS} must be manually edited."
    printf "\n${DIM}Remove the ExitPlanMode entry under PermissionRequest and the${NC}\n"
    printf "${DIM}plan-deepen entry under UserPromptSubmit, then save the file.${NC}\n\n"
  fi
fi

# ── Remove shell-rc alias block ─────────────────────────────────────
for RC_FILE in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
  if [ -f "$RC_FILE" ] && grep -qF "$ALIAS_MARK_BEGIN" "$RC_FILE" 2>/dev/null; then
    TMP_RC=$(mktemp)
    awk -v b="$ALIAS_MARK_BEGIN" -v e="$ALIAS_MARK_END" '
      $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
    ' "$RC_FILE" > "$TMP_RC" && mv "$TMP_RC" "$RC_FILE"
    ok "Removed effort-tier aliases from ${RC_FILE}"
  fi
done

printf "\n${GREEN}${BOLD}Uninstalled.${NC}\n"
printf "  ${DIM}Restart Claude Code (and open a new shell) for changes to take effect.${NC}\n\n"
