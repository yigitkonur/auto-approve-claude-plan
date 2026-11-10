#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook installer                                     ║
# ║  Auto-approve Claude Code plans — Classic or Deep Plan mode    ║
# ║                                                                  ║
# ║  curl -fsSL <raw>/install.sh | bash              # Classic       ║
# ║  curl -fsSL <raw>/install.sh | bash -s -- --deep # Deep Plan     ║
# ╚══════════════════════════════════════════════════════════════════╝

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOOK_DIR/claude-plan-hook.sh"
DEEPEN_SCRIPT="$HOOK_DIR/plan-deepen.sh"
BACKUP_DIR="$HOOK_DIR/.backups"

REPO_RAW="https://raw.githubusercontent.com/yigitkonur/auto-approve-claude-plan/main"

# ── Mode: 1 = Classic (default), 2 = Deep Plan. No prompts. ─────────
MODE="${CLAUDE_PLAN_HOOK_MODE:-1}"
for arg in "$@"; do
  case "$arg" in
    --classic) MODE=1 ;;
    --deep)    MODE=2 ;;
    -h|--help)
      printf "usage: install.sh [--classic | --deep]\n"
      printf "  --classic  auto-approve plans + land in bypassPermissions (default)\n"
      printf "  --deep     Classic + in-plan reasoning nudge + claude-plan/claude-fast aliases\n"
      exit 0 ;;
    *) printf "unknown option: %s (try --help)\n" "$arg"; exit 1 ;;
  esac
done
case "$MODE" in 1|2) ;; *) printf "CLAUDE_PLAN_HOOK_MODE must be 1 or 2\n"; exit 1 ;; esac

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
  info "jq not found — installing it..."
  if command -v brew &>/dev/null; then
    brew install jq >/dev/null
  elif command -v apt-get &>/dev/null; then
    SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    $SUDO apt-get install -y jq >/dev/null 2>&1 || { $SUDO apt-get update >/dev/null && $SUDO apt-get install -y jq >/dev/null; }
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y jq >/dev/null
  fi
  if ! command -v jq &>/dev/null; then
    err "jq is required and could not be installed automatically."
    printf "  ${DIM}brew install jq${NC}   # macOS\n"
    printf "  ${DIM}sudo apt install jq${NC}   # Debian/Ubuntu\n"
    exit 1
  fi
  ok "Installed jq"
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
  if [ -f "$DEEPEN_SCRIPT" ]; then
    warn "Already installed: Deep Plan mode — reinstalling."
  else
    warn "Already installed: Classic mode — reinstalling."
  fi

  # Backup old hook before overwriting
  mkdir -p "$BACKUP_DIR"
  TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
  cp -f "$HOOK_SCRIPT" "$BACKUP_DIR/claude-plan-hook.${TIMESTAMP}.sh"
  info "Backed up existing hook to ${BACKUP_DIR}/"

  rm -f "$HOOK_SCRIPT"
  printf "\n"
fi

# ── Install hook script(s) ──────────────────────────────────────────
mkdir -p "$HOOK_DIR"

# Use the local checkout only when run from a file; `curl | bash` and
# `bash <(curl ...)` download the hooks from GitHub instead.
SCRIPT_DIR=""
if [ -f "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Helper: place a repo file at a destination, from local checkout or GitHub.
place_file() {
  local src_rel="$1" dest="$2"
  if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/${src_rel}" ]; then
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

mkdir -p "$(dirname "$SETTINGS")"
if [ -f "$SETTINGS" ] && [ -n "$(tr -d '[:space:]' < "$SETTINGS")" ]; then
  # Backup settings.json before modifying
  mkdir -p "$BACKUP_DIR"
  TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
  cp -f "$SETTINGS" "$BACKUP_DIR/settings.${TIMESTAMP}.json"
  info "Backed up settings.json to ${BACKUP_DIR}/"
  SRC="$SETTINGS"
else
  SRC=$(mktemp)
  echo '{}' > "$SRC"
fi

TMP=$(mktemp)
trap 'rm -f "${TMP:-}"' EXIT

if ! jq --arg cmd "$HOOK_CMD" --arg deepen "$DEEPEN_CMD" --arg mode "$MODE" '
  # ── Satisfy the CC 2.1.110+ gate ────────────────────────────────────
  # A hook setMode:"bypassPermissions" is a silent no-op unless the
  # session is already bypass-eligible. Setting permissions.defaultMode
  # makes every session eligible. (Existing permissions.* keys preserved.)
  .permissions //= {} |
  .permissions.defaultMode = "bypassPermissions" |

  # ── effortLevel baseline (Deep Plan only, never clobbers a user choice)
  ( if $mode == "2" and (.effortLevel == null) then .effortLevel = "low" else . end ) |

  # ── Drop every entry pointing at our hooks, in any event, so reruns and
  # leftovers from older versions are cleaned up. Unrelated hooks stay.
  .hooks = ((.hooks // {}) | with_entries(
    .value = [ .value[] |
      .hooks = [(.hooks // [])[] | select((.command // "") | test("\\.claude/hooks/(claude-plan-hook|plan-deepen)\\.sh") | not)] |
      select(.hooks | length > 0) ]
  ) | with_entries(select(.value | length > 0))) |

  # ── Re-register ours ────────────────────────────────────────────────
  .hooks.PermissionRequest += [{
    "matcher": "ExitPlanMode",
    "hooks": [{"type": "command", "command": $cmd}]
  }] |
  ( if $mode == "2" then
      .hooks.UserPromptSubmit += [{"hooks": [{"type": "command", "command": $deepen}]}]
    else . end )
' "$SRC" > "$TMP" 2>/dev/null; then
  err "jq transform failed — settings.json not modified."
  exit 1
fi

# Validate the output is a JSON object before replacing
if ! jq -e 'type == "object"' "$TMP" >/dev/null 2>&1; then
  err "jq produced invalid JSON — settings.json not modified."
  exit 1
fi

[ "$SRC" != "$SETTINGS" ] && rm -f "$SRC"
mv "$TMP" "$SETTINGS"
ok "Updated ${SETTINGS}"

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
printf "  ${DIM}To switch modes, rerun with --classic or --deep.${NC}\n"
printf "  ${DIM}To uninstall: curl -fsSL ${REPO_RAW}/uninstall.sh | bash${NC}\n"
printf "\n"
