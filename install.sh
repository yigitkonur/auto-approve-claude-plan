#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook installer                                     ║
# ║  Auto-approve Claude Code plans — classic or orchestrator mode ║
# ╚══════════════════════════════════════════════════════════════════╝

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claude-plan-hook.sh"
BACKUP_DIR="$HOOK_DIR/.backups"

REPO_RAW="https://raw.githubusercontent.com/yigitkonur/auto-approve-claude-plan/main"

# ── Colors ───────────────────────────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  BOLD=''
  DIM=''
fi
NC='\033[0m'

ok()   { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[!!]${NC} %s\n" "$1"; }
err()  { printf "${RED}[err]${NC} %s\n" "$1"; }
info() { printf "${CYAN}[..]${NC} %s\n" "$1"; }

# ── Banner ───────────────────────────────────────────────────────────
printf "\n"
printf "${BOLD}  claude-plan-hook${NC}\n"
printf "${DIM}  Auto-approve Claude Code plans. Stop clicking buttons.${NC}\n"
printf "\n"

# ── Prerequisites ────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  err "jq is required but not installed."
  printf "  ${DIM}brew install jq${NC}   # macOS\n"
  printf "  ${DIM}sudo apt install jq${NC}   # Debian/Ubuntu\n"
  exit 1
fi

# ── Validate existing settings.json ─────────────────────────────────
if [ -f "$SETTINGS" ]; then
  if ! jq empty "$SETTINGS" 2>/dev/null; then
    err "settings.json is not valid JSON — refusing to modify."
    printf "  ${DIM}Fix ${SETTINGS} manually, then re-run the installer.${NC}\n"
    exit 1
  fi
fi

# ── Detect & clean existing install ──────────────────────────────────
if [ -f "$HOOK_SCRIPT" ]; then
  if grep -q "Orchestrator" "$HOOK_SCRIPT" 2>/dev/null; then
    warn "Already installed: Orchestrator mode"
  elif grep -q "Classic" "$HOOK_SCRIPT" 2>/dev/null; then
    warn "Already installed: Classic mode"
  else
    warn "Already installed: unrecognized version"
  fi

  # Backup old hook before overwriting
  mkdir -p "$BACKUP_DIR"
  TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
  cp -f "$HOOK_SCRIPT" "$BACKUP_DIR/claude-plan-hook.${TIMESTAMP}.sh"
  info "Backed up existing hook to ${BACKUP_DIR}/"

  rm -f "$HOOK_SCRIPT"
  printf "\n"
fi

# ── Mode selection ───────────────────────────────────────────────────
printf "${BOLD}Choose a mode:${NC}\n\n"
printf "  ${BOLD}1${NC}  Classic\n"
printf "     ${DIM}Auto-approve plans instantly. Simple and silent.${NC}\n\n"
printf "  ${BOLD}2${NC}  Orchestrator ${DIM}(recommended)${NC}\n"
printf "     ${DIM}Auto-approve + inject a directive that makes Claude execute${NC}\n"
printf "     ${DIM}plans with precision, spawn subagents for complex tasks,${NC}\n"
printf "     ${DIM}and enforce strict BSV completion criteria.${NC}\n\n"

while true; do
  printf "${CYAN}>${NC} Enter mode [1/2]: "
  read -r MODE
  case "$MODE" in
    1|2) break ;;
    *) err "Please enter 1 or 2." ;;
  esac
done
printf "\n"

# ── Install hook script ─────────────────────────────────────────────
mkdir -p "$HOOK_DIR"

case "$MODE" in
  1) HOOK_SRC="hooks/auto-approve-plan.sh" ;;
  2) HOOK_SRC="hooks/auto-approve-orchestrator.sh" ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
if [ -f "${SCRIPT_DIR}/install.sh" ] && [ -f "${SCRIPT_DIR}/${HOOK_SRC}" ]; then
  cp -f "${SCRIPT_DIR}/${HOOK_SRC}" "$HOOK_SCRIPT"
else
  info "Downloading hook script from GitHub..."
  if ! curl -fsSL "${REPO_RAW}/${HOOK_SRC}" -o "$HOOK_SCRIPT"; then
    err "Failed to download hook script."
    exit 1
  fi
fi

# Validate the hook script is not empty / truncated
if [ ! -s "$HOOK_SCRIPT" ]; then
  err "Hook script is empty — download may have failed."
  exit 1
fi

chmod +x "$HOOK_SCRIPT"
ok "Hook script installed to ${HOOK_SCRIPT}"

# ── Update settings.json ────────────────────────────────────────────
HOOK_CMD="~/.claude/hooks/claude-plan-hook.sh"

if [ ! -f "$SETTINGS" ]; then
  if [ "$MODE" = "2" ]; then
    cat > "$SETTINGS" <<ENDJSON
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [{"type": "command", "command": "${HOOK_CMD}"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [{"type": "command", "command": "${HOOK_CMD}"}]
      }
    ]
  }
}
ENDJSON
  else
    cat > "$SETTINGS" <<ENDJSON
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [{"type": "command", "command": "${HOOK_CMD}"}]
      }
    ]
  }
}
ENDJSON
  fi
  ok "Created ${SETTINGS}"
else
  # Backup settings.json before modifying
  mkdir -p "$BACKUP_DIR"
  TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
  cp -f "$SETTINGS" "$BACKUP_DIR/settings.${TIMESTAMP}.json"
  info "Backed up settings.json to ${BACKUP_DIR}/"

  TMP=$(mktemp)
  trap 'rm -f "${TMP:-}"' EXIT

  if ! jq --arg cmd "$HOOK_CMD" --arg mode "$MODE" '
    .hooks //= {} |
    # PermissionRequest: drop any existing entry that points at our hook
    # (whether matched by ExitPlanMode or by command path), then re-add.
    .hooks.PermissionRequest //= [] |
    .hooks.PermissionRequest = [
      .hooks.PermissionRequest[] |
      .hooks = [(.hooks // [])[] | select((.command // "") | test("auto-approve|claude-plan-hook"; "i") | not)] |
      select((.hooks // []) | length > 0)
    ] |
    .hooks.PermissionRequest += [{
      "matcher": "ExitPlanMode",
      "hooks": [{"type": "command", "command": $cmd}]
    }] |
    # PostToolUse: always scrub any existing entry that points at our hook,
    # by command path (not just matcher) so an old orchestrator install is
    # fully removed when reinstalling in Classic mode.
    .hooks.PostToolUse //= [] |
    .hooks.PostToolUse = [
      .hooks.PostToolUse[] |
      .hooks = [(.hooks // [])[] | select((.command // "") | test("auto-approve|claude-plan-hook"; "i") | not)] |
      select((.hooks // []) | length > 0)
    ] |
    # Only Orchestrator (mode 2) re-adds the PostToolUse entry.
    ( if $mode == "2" then
        .hooks.PostToolUse += [{
          "matcher": "ExitPlanMode",
          "hooks": [{"type": "command", "command": $cmd}]
        }]
      else . end ) |
    ( if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end ) |
    if .hooks.Stop then
      .hooks.Stop = [
        .hooks.Stop[] |
        .hooks = [(.hooks // [])[] | select(.command | test("auto-approve|claude-plan-hook"; "i") | not)]
      ] |
      .hooks.Stop = [.hooks.Stop[] | select((.hooks // []) | length > 0)]
    else . end |
    if .hooks.Stop == [] then del(.hooks.Stop) else . end
  ' "$SETTINGS" > "$TMP" 2>/dev/null; then
    err "jq transform failed — settings.json not modified."
    rm -f "$TMP"
    exit 1
  fi

  # Validate the output is valid JSON before replacing
  if ! jq empty "$TMP" 2>/dev/null; then
    err "jq produced invalid JSON — settings.json not modified."
    rm -f "$TMP"
    exit 1
  fi

  # Verify output is not empty / smaller than a sane minimum
  NEW_SIZE=$(wc -c < "$TMP" | tr -d ' ')
  if [ "$NEW_SIZE" -lt 10 ]; then
    err "jq output too small (${NEW_SIZE} bytes) — settings.json not modified."
    rm -f "$TMP"
    exit 1
  fi

  mv "$TMP" "$SETTINGS"
  ok "Updated ${SETTINGS}"
fi

# ── Prune old backups (keep last 5) ────────────────────────────────
if [ -d "$BACKUP_DIR" ]; then
  # shellcheck disable=SC2012
  ls -t "$BACKUP_DIR"/settings.*.json 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
  ls -t "$BACKUP_DIR"/claude-plan-hook.*.sh 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
fi

# ── Summary ──────────────────────────────────────────────────────────
printf "\n"
printf "${GREEN}${BOLD}Installed!${NC}\n\n"

case "$MODE" in
  1)
    printf "  Mode:   ${BOLD}Classic${NC}\n"
    printf "  Effect: Plans are approved instantly. No bells, no whistles.\n"
    ;;
  2)
    printf "  Mode:   ${BOLD}Orchestrator${NC}\n"
    printf "  Effect: Plans are approved instantly. Claude receives a directive\n"
    printf "          to execute step-by-step, delegate via subagents for complex\n"
    printf "          tasks, and enforce 100%% completion with BSV criteria.\n"
    ;;
esac

printf "\n"
printf "  ${DIM}Restart Claude Code for changes to take effect.${NC}\n"
printf "  ${DIM}To switch modes, run the installer again.${NC}\n"
printf "  ${DIM}To uninstall: curl -fsSL ${REPO_RAW}/uninstall.sh | bash${NC}\n"
printf "\n"
