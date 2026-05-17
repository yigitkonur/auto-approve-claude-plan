#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook: Classic — Auto-Approve + bypassPermissions   ║
# ║                                                                  ║
# ║  Returns "allow" so Claude proceeds without the approval dialog. ║
# ║  Also emits the documented updatedPermissions payload so the     ║
# ║  session lands in bypassPermissions after ExitPlanMode instead   ║
# ║  of falling back to acceptEdits.                                 ║
# ║                                                                  ║
# ║  Schema source: code.claude.com/docs/en/hooks                    ║
# ║                                                                  ║
# ║  Known upstream issues:                                          ║
# ║    - anthropics/claude-code#49525                                ║
# ║      mode:"bypassPermissions" is silently dropped on CC 2.1.110+ ║
# ║      Other modes (default|acceptEdits|dontAsk|plan) still apply. ║
# ║      Self-fixing once Anthropic ships the patch.                 ║
# ║    - anthropics/claude-code#39973                                ║
# ║      ExitPlanMode resets the mode to acceptEdits regardless of   ║
# ║      the prior session mode.                                     ║
# ║                                                                  ║
# ║  Prerequisite for bypass to land: the session must be bypass-    ║
# ║  eligible — launch with `claude --permission-mode               ║
# ║  bypassPermissions` or set `permissions.defaultMode` to          ║
# ║  "bypassPermissions" in ~/.claude/settings.json, and ensure      ║
# ║  `permissions.disableBypassPermissionsMode` is not set.          ║
# ╚══════════════════════════════════════════════════════════════════╝

cat > /dev/null

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedPermissions": [
        {"type": "setMode", "mode": "bypassPermissions", "destination": "session"}
      ],
      "message": "Plan auto-approved; requested bypassPermissions"
    }
  }
}
EOF

exit 0
