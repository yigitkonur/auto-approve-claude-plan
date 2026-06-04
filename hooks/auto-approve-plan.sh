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
# ║  The "bypassPermissions" mode value is current and unchanged     ║
# ║  (verified against the live docs, 2026-06): valid setMode modes  ║
# ║  are default|auto|acceptEdits|dontAsk|bypassPermissions|plan.     ║
# ║                                                                  ║
# ║  THE GATE (CC 2.1.110+): a hook setMode:"bypassPermissions" is   ║
# ║  a silent no-op UNLESS the session was launched bypass-eligible. ║
# ║  Otherwise it falls back to acceptEdits. This is documented,     ║
# ║  intentional behaviour — anthropics/claude-code#49525 was closed ║
# ║  as not-planned, so it does NOT self-fix. Other modes apply      ║
# ║  unconditionally; only bypassPermissions is gated.               ║
# ║                                                                  ║
# ║  Prerequisite (the actual fix — set by install.sh): make the     ║
# ║  session bypass-eligible via permissions.defaultMode =           ║
# ║  "bypassPermissions" in settings.json, or launch with            ║
# ║  `claude --permission-mode bypassPermissions` /                  ║
# ║  `--dangerously-skip-permissions`, and ensure                    ║
# ║  permissions.disableBypassPermissionsMode is NOT set (it gates   ║
# ║  bypass off even when defaultMode is set).                       ║
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
