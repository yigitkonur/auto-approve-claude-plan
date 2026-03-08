#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook: Classic — Auto-Approve                       ║
# ║                                                                  ║
# ║  Returns "allow" so Claude proceeds without the approval dialog.║
# ╚══════════════════════════════════════════════════════════════════╝

cat > /dev/null

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "message": "Plan auto-approved"
    }
  }
}
EOF

exit 0
