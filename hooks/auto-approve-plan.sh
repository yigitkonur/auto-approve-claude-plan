#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook: Classic — Auto-Approve + setMode              ║
# ║                                                                  ║
# ║  Returns "allow" so Claude proceeds without the approval dialog. ║
# ║  Also emits setMode="dontAsk" so the post-exit landing mode is   ║
# ║  "dontAsk" instead of the hardcoded "acceptEdits" fallback.      ║
# ║                                                                  ║
# ║  setMode is undocumented; accepted values per Issue #45284:      ║
# ║    default | acceptEdits | dontAsk | plan                        ║
# ║  bypassPermissions is NOT selectable from a hook.                ║
# ║  On Claude Code v2.1.118+, the prior session mode is restored    ║
# ║  after ExitPlanMode and may override setMode — that is fine, the ║
# ║  allow decision is what skips the dialog regardless.             ║
# ╚══════════════════════════════════════════════════════════════════╝

cat > /dev/null

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "setMode": "dontAsk",
      "message": "Plan auto-approved; mode set to dontAsk"
    }
  }
}
EOF

exit 0
