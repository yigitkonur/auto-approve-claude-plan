#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook installer                                     ║
# ║  Auto-approve Claude Code plans — Classic or Deep Plan mode    ║
# ╚══════════════════════════════════════════════════════════════════╝

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claude-plan-hook.sh"
DEEPEN_SCRIPT="$HOOK_DIR/plan-deepen.sh"
BACKUP_DIR="$HOOK_DIR/.backups"

REPO_RAW="https://raw.githubusercontent.com/yigitkonur/auto-approve-claude-plan/main"

# Marker that brackets the shell-rc alias block (used for idempotent add/remove)
ALIAS_MARK_BEGIN="# >>> claude-plan-hook effort tiers >>>"
ALIAS_MARK_END="# <<< claude-plan-hook effort tiers <<<"

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
  if grep -q "Deep Plan" "$HOOK_SCRIPT" 2>/dev/null; then
    warn "Already installed: Deep Plan mode"
  elif grep -q "Classic" "$HOOK_SCRIPT" 2>/dev/null; then
    warn "Already installed: Classic mode"
  elif grep -q "Orchestrator" "$HOOK_SCRIPT" 2>/dev/null; then
    warn "Found legacy Orchestrator install — it will be replaced."
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
printf "  ${BOLD}1${NC}  Classic ${DIM}— default bypass${NC}\n"
printf "     ${DIM}Auto-approve plans instantly and land the session in${NC}\n"
printf "     ${DIM}bypassPermissions. Simple and silent. Nothing else touched.${NC}\n\n"
printf "  ${BOLD}2${NC}  Deep Plan ${DIM}(recommended)${NC}\n"
printf "     ${DIM}Everything in Classic, PLUS: while you are IN plan mode, a${NC}\n"
printf "     ${DIM}UserPromptSubmit hook injects deep-reasoning guidance so${NC}\n"
printf "     ${DIM}planning runs deliberately; it auto-stops once you leave${NC}\n"
printf "     ${DIM}plan mode. Sets effortLevel=low as the cheap normal-mode${NC}\n"
printf "     ${DIM}baseline and adds 'claude-plan' / 'claude-fast' shell aliases.${NC}\n"
printf "     ${DIM}Note: the in-plan boost is a PROMPT nudge, not the real${NC}\n"
printf "     ${DIM}effort knob (hooks cannot set effort). 'claude-plan' is the${NC}\n"
printf "     ${DIM}real max-effort launch. See the README for the why.${NC}\n\n"

while true; do
  printf "${CYAN}>${NC} Enter mode [1/2]: "
  read -r MODE
  case "$MODE" in
    1|2) break ;;
    *) err "Please enter 1 or 2." ;;
  esac
done
printf "\n"

# ── Install hook script(s) ──────────────────────────────────────────
mkdir -p "$HOOK_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"

# Helper: place a repo file at a destination, from local checkout or GitHub.
place_file() {
  local src_rel="$1" dest="$2"
  if [ -f "${SCRIPT_DIR}/${src_rel}" ]; then
    cp -f "${SCRIPT_DIR}/${src_rel}" "$dest"
  else
    info "Downloading ${src_rel} from GitHub..."
    if ! curl -fsSL "${REPO_RAW}/${src_rel}" -o "$dest"; then
      err "Failed to download ${src_rel}."
      exit 1
    fi
  fi
  if [ ! -s "$dest" ]; then
    err "${dest} is empty — download may have failed."
    exit 1
  fi
  chmod +x "$dest"
}

# The auto-approve hook is identical in both modes.
place_file "hooks/auto-approve-plan.sh" "$HOOK_SCRIPT"
ok "Hook script installed to ${HOOK_SCRIPT}"

if [ "$MODE" = "2" ]; then
  place_file "hooks/plan-deepen.sh" "$DEEPEN_SCRIPT"
  ok "Deep Plan hook installed to ${DEEPEN_SCRIPT}"
else
  # Classic: remove any Deep Plan hook left over from a prior install.
  rm -f "$DEEPEN_SCRIPT"
fi

# ── Update settings.json ────────────────────────────────────────────
HOOK_CMD="~/.claude/hooks/claude-plan-hook.sh"
DEEPEN_CMD="~/.claude/hooks/plan-deepen.sh"

if [ ! -f "$SETTINGS" ]; then
  if [ "$MODE" = "2" ]; then
    cat > "$SETTINGS" <<ENDJSON
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "effortLevel": "low",
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [{"type": "command", "command": "${HOOK_CMD}"}]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [{"type": "command", "command": "${DEEPEN_CMD}"}]
      }
    ]
  }
}
ENDJSON
  else
    cat > "$SETTINGS" <<ENDJSON
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
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

  if ! jq --arg cmd "$HOOK_CMD" --arg deepen "$DEEPEN_CMD" --arg mode "$MODE" '
    # ── Satisfy the CC 2.1.110+ gate ──────────────────────────────────
    # A hook setMode:"bypassPermissions" is a silent no-op unless the
    # session is already bypass-eligible. Setting permissions.defaultMode
    # makes every session eligible so the hook actually lands bypass after
    # ExitPlanMode instead of falling back to acceptEdits. (Existing
    # permissions.* keys preserved.)
    .permissions //= {} |
    .permissions.defaultMode = "bypassPermissions" |

    # ── effortLevel baseline (Deep Plan only) ─────────────────────────
    # Deep Plan needs a cheap normal-mode floor so the in-plan boost has
    # contrast. We set "low" only when effortLevel is unset, so we never
    # clobber an explicit user choice.
    ( if $mode == "2" and (.effortLevel == null) then .effortLevel = "low" else . end ) |

    .hooks //= {} |

    # ── PermissionRequest / ExitPlanMode: re-register our auto-approve ─
    # Drop any prior entry pointing at our hooks, then re-add cleanly.
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

    # ── PostToolUse: scrub legacy Orchestrator entries entirely ────────
    # The old Orchestrator mode injected on PostToolUse/ExitPlanMode. That
    # mode is removed; strip any entry that points at our hooks.
    .hooks.PostToolUse //= [] |
    .hooks.PostToolUse = [
      .hooks.PostToolUse[] |
      .hooks = [(.hooks // [])[] | select((.command // "") | test("auto-approve|claude-plan-hook"; "i") | not)] |
      select((.hooks // []) | length > 0)
    ] |
    ( if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end ) |

    # ── UserPromptSubmit / plan-deepen ────────────────────────────────
    # Always scrub our prior plan-deepen entry first (idempotent), keeping
    # any unrelated UserPromptSubmit hooks (e.g. status-line integrations).
    .hooks.UserPromptSubmit //= [] |
    .hooks.UserPromptSubmit = [
      .hooks.UserPromptSubmit[] |
      .hooks = [(.hooks // [])[] | select((.command // "") | test("plan-deepen"; "i") | not)] |
      select((.hooks // []) | length > 0)
    ] |
    # Only Deep Plan (mode 2) re-adds the plan-deepen entry.
    ( if $mode == "2" then
        .hooks.UserPromptSubmit += [{
          "hooks": [{"type": "command", "command": $deepen}]
        }]
      else . end ) |
    ( if .hooks.UserPromptSubmit == [] then del(.hooks.UserPromptSubmit) else . end ) |

    # ── Legacy Stop cleanup (older revisions wired Stop) ──────────────
    if .hooks.Stop then
      .hooks.Stop = [
        .hooks.Stop[] |
        .hooks = [(.hooks // [])[] | select((.command // "") | test("auto-approve|claude-plan-hook|plan-deepen"; "i") | not)]
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

# ── Shell aliases (Deep Plan only) ──────────────────────────────────
# claude-plan = launch whole session at MAX effort (the real knob; also
#   dodges the settings.json effortLevel:"max" downgrade bug #43322).
# claude-fast = force LOW effort regardless of settings.
RC_FILE=""
case "${SHELL:-}" in
  *zsh*)  RC_FILE="$HOME/.zshrc" ;;
  *bash*) RC_FILE="$HOME/.bashrc" ;;
  *)      RC_FILE="${HOME}/.profile" ;;
esac

if [ "$MODE" = "2" ]; then
  if [ -n "$RC_FILE" ]; then
    # Remove any prior block first (idempotent), then append a fresh one.
    if [ -f "$RC_FILE" ] && grep -qF "$ALIAS_MARK_BEGIN" "$RC_FILE" 2>/dev/null; then
      TMP_RC=$(mktemp)
      awk -v b="$ALIAS_MARK_BEGIN" -v e="$ALIAS_MARK_END" '
        $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
      ' "$RC_FILE" > "$TMP_RC" && mv "$TMP_RC" "$RC_FILE"
    fi
    {
      printf '\n%s\n' "$ALIAS_MARK_BEGIN"
      printf '# Effort is locked at launch; settings.json default is "low" (normal mode stays cheap).\n'
      printf '# In-plan deepening is handled by ~/.claude/hooks/plan-deepen.sh (a prompt nudge).\n'
      printf '#   claude-plan : launch entire session at MAX effort (real knob; dodges bug #43322)\n'
      printf '#   claude-fast : force LOW effort regardless of settings\n'
      printf "alias claude-plan='CLAUDE_CODE_EFFORT_LEVEL=max claude'\n"
      printf "alias claude-fast='CLAUDE_CODE_EFFORT_LEVEL=low claude'\n"
      printf '%s\n' "$ALIAS_MARK_END"
    } >> "$RC_FILE"
    ok "Added claude-plan / claude-fast aliases to ${RC_FILE}"
  else
    warn "Could not determine a shell rc file — add the aliases manually (see README)."
  fi
else
  # Classic: remove the alias block if a prior Deep Plan install left one.
  if [ -n "$RC_FILE" ] && [ -f "$RC_FILE" ] && grep -qF "$ALIAS_MARK_BEGIN" "$RC_FILE" 2>/dev/null; then
    TMP_RC=$(mktemp)
    awk -v b="$ALIAS_MARK_BEGIN" -v e="$ALIAS_MARK_END" '
      $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
    ' "$RC_FILE" > "$TMP_RC" && mv "$TMP_RC" "$RC_FILE"
    info "Removed leftover effort-tier aliases from ${RC_FILE}"
  fi
fi

# ── Warn if bypass is blocked by policy ─────────────────────────────
# Even with permissions.defaultMode set, CC 2.1.110+ honours
# disableBypassPermissionsMode — if it's on, the hook's setMode is a no-op.
if [ -f "$SETTINGS" ] && \
   [ "$(jq -r '.permissions.disableBypassPermissionsMode // empty' "$SETTINGS" 2>/dev/null)" = "true" ]; then
  warn "permissions.disableBypassPermissionsMode is enabled — bypassPermissions will NOT land."
  printf "  ${DIM}Remove it (or a managed policy setting it) for the hook to take effect.${NC}\n"
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
    printf "  Effect: Plans are approved instantly and the session lands in\n"
    printf "          bypassPermissions. No bells, no whistles.\n"
    ;;
  2)
    printf "  Mode:   ${BOLD}Deep Plan${NC}\n"
    printf "  Effect: Plans are approved instantly (bypassPermissions). While in\n"
    printf "          plan mode, Claude is nudged to reason deeply; effortLevel is\n"
    printf "          set to low for cheap normal-mode turns. Use ${BOLD}claude-plan${NC} to\n"
    printf "          launch a session at true MAX effort.\n"
    ;;
esac

printf "\n"
printf "  ${DIM}Restart Claude Code for changes to take effect.${NC}\n"
if [ "$MODE" = "2" ]; then
  printf "  ${DIM}Run 'source ${RC_FILE}' (or open a new shell) to load the aliases.${NC}\n"
  printf "  ${DIM}The in-plan boost is a prompt nudge, not the effort knob — see README.${NC}\n"
fi
printf "  ${DIM}To switch modes, run the installer again.${NC}\n"
printf "  ${DIM}To uninstall: curl -fsSL ${REPO_RAW}/uninstall.sh | bash${NC}\n"
printf "\n"
